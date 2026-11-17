import 'dart:ui' show ImageFilter;
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

  /// Generic confirmation modal with frosted backdrop blur
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
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 7, sigmaY: 7),
        child: AppConfirmationDialog(
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
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 7, sigmaY: 7),
        child: AppConfirmationDialog(
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
              // FinTech Payment Transition Card
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: const Icon(
                        Icons.swap_horiz_rounded,
                        size: 20,
                        color: Color(0xFF475569),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'PAYMENT METHOD SWITCH',
                            style: GoogleFonts.inter(
                              fontSize: Responsive.scaledFontSize(context, 9.5),
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                              color: const Color(0xFF94A3B8),
                            ),
                          ),
                          const SizedBox(height: 3),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Row(
                              children: [
                                Text(
                                  'Online',
                                  style: GoogleFonts.inter(
                                    fontSize: Responsive.scaledFontSize(context, 12),
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF94A3B8),
                                    decoration: TextDecoration.lineThrough,
                                    decorationColor: const Color(0xFF94A3B8),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Icon(
                                  Icons.arrow_forward_rounded,
                                  size: 13,
                                  color: Color(0xFF16A34A),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Cash on Delivery',
                                  style: GoogleFonts.inter(
                                    fontSize: Responsive.scaledFontSize(context, 12.5),
                                    fontWeight: FontWeight.w900,
                                    color: const Color(0xFF0F172A),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              // Kitchen / Delivery status cue badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFDCFCE7)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.flash_on_rounded, size: 14, color: Color(0xFF16A34A)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        queueMessage,
                        style: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 11),
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF15803D),
                        ),
                      ),
                    ),
                  ],
                ),
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
    ),
  );
  }

  /// Modern Universal Logout Dialog with frosted backdrop & security badge
  static Future<bool?> showLogout({
    required BuildContext context,
    String title = 'Log Out of FastMinute?',
    String subtitle = 'You will need to verify your phone number or email to log back in.',
    String confirmLabel = 'Log Out',
    String? accountNote,
  }) {
    HapticFeedback.lightImpact();
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 7, sigmaY: 7),
        child: AppConfirmationDialog(
          icon: Icons.logout_rounded,
          title: title,
          message: subtitle,
          type: ConfirmationDialogType.danger,
          confirmLabel: confirmLabel,
          cancelLabel: 'Cancel',
          confirmIcon: Icons.power_settings_new_rounded,
          contentWidget: accountNote != null
              ? Container(
                  width: double.infinity,
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF1F2),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFFECDD3), width: 1),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFE4E6),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFFECDD3), width: 1),
                        ),
                        child: const Icon(
                          Icons.verified_user_rounded,
                          size: 17,
                          color: Color(0xFFE11D48),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          accountNote,
                          style: GoogleFonts.inter(
                            fontSize: Responsive.scaledFontSize(context, 11.5),
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF9F1239),
                            height: 1.38,
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
      ),
    );
  }

  /// Ultra-Premium Clear Cart Dialog with frosted backdrop & context pill
  static Future<bool?> showClearCart({
    required BuildContext context,
    int? itemCount,
    String? storeName,
    String title = 'Clear Entire Cart?',
    String confirmLabel = 'Clear Cart',
    String cancelLabel = 'Cancel',
  }) {
    HapticFeedback.lightImpact();
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 7, sigmaY: 7),
        child: AppConfirmationDialog(
          icon: Icons.remove_shopping_cart_rounded,
          title: title,
          message: itemCount != null && itemCount > 0
              ? 'Are you sure you want to remove all $itemCount items from your cart?'
              : 'Are you sure you want to remove all items from your cart?',
          type: ConfirmationDialogType.danger,
          confirmLabel: confirmLabel,
          cancelLabel: cancelLabel,
          confirmIcon: Icons.delete_sweep_rounded,
          contentWidget: Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF1F2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFFECDD3), width: 1),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFE4E6),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFECDD3), width: 1),
                  ),
                  child: const Icon(
                    Icons.shopping_bag_outlined,
                    size: 17,
                    color: Color(0xFFE11D48),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    storeName != null && storeName.isNotEmpty
                        ? 'All selected items and cooking instructions for $storeName will be removed.'
                        : 'All selected items and customized cooking instructions will be removed.',
                    style: GoogleFonts.inter(
                      fontSize: Responsive.scaledFontSize(context, 11.5),
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF9F1239),
                      height: 1.38,
                    ),
                  ),
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
      ),
    );
  }

  /// Modern Destructive Action (e.g. Delete Address, Cancel Order)
  static Future<bool?> showDestructive({
    required BuildContext context,
    required String title,
    required String message,
    required String confirmLabel,
    String cancelLabel = 'Cancel',
    IconData icon = Icons.delete_outline_rounded,
    Widget? contentWidget,
  }) {
    HapticFeedback.lightImpact();
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 7, sigmaY: 7),
        child: AppConfirmationDialog(
          icon: icon,
          title: title,
          message: message,
          type: ConfirmationDialogType.danger,
          confirmLabel: confirmLabel,
          cancelLabel: cancelLabel,
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
        return const Color(0xFFE11D48); // Rose 600 / FastMinute Red
      case ConfirmationDialogType.warning:
        return const Color(0xFFF59E0B); // Amber 500
      case ConfirmationDialogType.info:
        return const Color(0xFF2563EB); // Blue 600
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: 0.16),
              blurRadius: 28,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 1. Concentric 3-Layer Depth Icon Badge
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 74,
                  height: 74,
                  decoration: BoxDecoration(
                    color: _primaryColor.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                ),
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: _badgeBgColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: _badgeBorderColor, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: _primaryColor.withValues(alpha: 0.16),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      icon,
                      size: 26,
                      color: _primaryColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // 2. Headline with Plus Jakarta Sans
            Text(
              title,
              style: GoogleFonts.plusJakartaSans(
                fontSize: Responsive.scaledFontSize(context, 18),
                fontWeight: FontWeight.w900,
                color: const Color(0xFF0F172A),
                letterSpacing: -0.4,
              ),
              textAlign: TextAlign.center,
            ),

            // 3. Subtitle / Message
            if (message != null) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  message!,
                  style: GoogleFonts.inter(
                    fontSize: Responsive.scaledFontSize(context, 13),
                    fontWeight: FontWeight.w400,
                    color: const Color(0xFF64748B),
                    height: 1.45,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],

            // 4. Custom Slot (Notice / Security / COD Switch Card)
            if (contentWidget != null) ...[
              const SizedBox(height: 16),
              contentWidget!,
            ],

            const SizedBox(height: 22),

            // 5. Dual Action Buttons with Dynamic Flex Allocation
            Builder(
              builder: (ctx) {
                final isLongConfirm = confirmLabel.length > 10;
                final cancelFlex = isLongConfirm ? 2 : 1;
                final confirmFlex = isLongConfirm ? 3 : 1;

                return Row(
                  children: [
                    // Cancel Button (Soft Neutral Slate with subtle border)
                    Expanded(
                      flex: cancelFlex,
                      child: SizedBox(
                        height: 48,
                        child: TextButton(
                          style: TextButton.styleFrom(
                            backgroundColor: const Color(0xFFF1F5F9),
                            foregroundColor: const Color(0xFF334155),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: const BorderSide(color: Color(0xFFE2E8F0), width: 1),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 0, horizontal: 8),
                          ),
                          onPressed: () {
                            if (onCancel != null) {
                              onCancel!();
                            } else {
                              Navigator.of(context).pop(false);
                            }
                          },
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              cancelLabel,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: Responsive.scaledFontSize(context, 13.5),
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF334155),
                              ),
                              maxLines: 1,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Confirm Button (Vibrant gradient with soft colored shadow)
                    Expanded(
                      flex: confirmFlex,
                      child: SizedBox(
                        height: 48,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            gradient: LinearGradient(
                              colors: type == ConfirmationDialogType.danger
                                  ? const [Color(0xFFE11D48), Color(0xFFBE123C)]
                                  : type == ConfirmationDialogType.success
                                      ? const [Color(0xFF10B981), Color(0xFF059669)]
                                      : type == ConfirmationDialogType.warning
                                          ? const [Color(0xFFF59E0B), Color(0xFFD97706)]
                                          : const [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: _primaryColor.withValues(alpha: 0.32),
                                blurRadius: 14,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
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
                                : FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (confirmIcon != null) ...[
                                          Icon(confirmIcon, size: 16.5, color: Colors.white),
                                          const SizedBox(width: 6),
                                        ],
                                        Text(
                                          confirmLabel,
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: Responsive.scaledFontSize(context, 13.5),
                                            fontWeight: FontWeight.w800,
                                            color: Colors.white,
                                            letterSpacing: -0.2,
                                          ),
                                          maxLines: 1,
                                        ),
                                      ],
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
