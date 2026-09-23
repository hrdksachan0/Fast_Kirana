import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_bounceable/flutter_bounceable.dart';
import '../core/theme/design_system.dart';
import '../providers/cart_provider.dart';

class HubConflictDialog extends ConsumerWidget {
  final String oldHubName;
  final String newHubName;

  const HubConflictDialog({
    super.key,
    required this.oldHubName,
    required this.newHubName,
  });

  /// Shows the conflict dialog. Returns true if user chose to clear cart & switch, false if cancelled.
  static Future<bool> show(
    BuildContext context, {
    required String oldHubName,
    required String newHubName,
  }) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => HubConflictDialog(
        oldHubName: oldHubName,
        newHubName: newHubName,
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Color(0x2A000000),
            blurRadius: 32,
            offset: Offset(0, -6),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle Bar
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppDesignSystem.slate200,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),

            // Warning Icon
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.2), width: 2),
              ),
              child: const Center(
                child: Icon(Icons.remove_shopping_cart_rounded, color: Color(0xFFDC2626), size: 28),
              ),
            ),
            const SizedBox(height: 16),

            // Title
            Text(
              'Switch Delivery Hub?',
              style: GoogleFonts.outfit(
                fontSize: Responsive.scaledFontSize(context, 19),
                fontWeight: FontWeight.w800,
                color: AppDesignSystem.slate900,
              ),
            ),
            const SizedBox(height: 8),

            // Body
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: GoogleFonts.inter(
                  fontSize: Responsive.scaledFontSize(context, 13.5),
                  fontWeight: FontWeight.w500,
                  color: AppDesignSystem.slate600,
                  height: 1.45,
                ),
                children: [
                  const TextSpan(text: 'Your cart has products from '),
                  TextSpan(
                    text: oldHubName,
                    style: const TextStyle(fontWeight: FontWeight.w700, color: AppDesignSystem.slate900),
                  ),
                  const TextSpan(text: '. Switching delivery location to '),
                  TextSpan(
                    text: newHubName,
                    style: const TextStyle(fontWeight: FontWeight.w700, color: AppDesignSystem.slate900),
                  ),
                  const TextSpan(text: ' will reset your current cart items.'),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Action Buttons
            Row(
              children: [
                // Cancel / Keep Current
                Expanded(
                  child: Bounceable(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      Navigator.pop(context, false);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      decoration: BoxDecoration(
                        color: AppDesignSystem.slate100,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                        child: Text(
                          'Keep Current',
                          style: GoogleFonts.inter(
                            fontSize: Responsive.scaledFontSize(context, 13.5),
                            fontWeight: FontWeight.w700,
                            color: AppDesignSystem.slate700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Clear & Switch
                Expanded(
                  child: Bounceable(
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      ref.read(cartProvider.notifier).clearCart();
                      Navigator.pop(context, true);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      decoration: BoxDecoration(
                        color: AppDesignSystem.red600,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: AppDesignSystem.red600.withValues(alpha: 0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          'Clear Cart & Switch',
                          style: GoogleFonts.inter(
                            fontSize: Responsive.scaledFontSize(context, 13.5),
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
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
