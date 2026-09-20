import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/design_system.dart';

/// Empty state display for Live Orders and Order History in Admin Console
class AdminOrdersEmptyView extends StatelessWidget {
  final bool isLive;
  final VoidCallback onRefresh;

  const AdminOrdersEmptyView({
    super.key,
    required this.isLive,
    required this.onRefresh,
  });

  static const Color primaryRed = AppDesignSystem.primary;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: isLive ? AppDesignSystem.statusCancelled : AppDesignSystem.slate100,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isLive ? primaryRed.withValues(alpha: 0.2) : AppDesignSystem.slate200,
                  width: 2,
                ),
              ),
              child: Center(
                child: Icon(
                  isLive ? Icons.bolt_rounded : Icons.history_toggle_off_rounded,
                  size: 34,
                  color: isLive ? primaryRed : AppDesignSystem.slate500,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isLive ? 'No Active Live Orders' : 'No Order History Yet',
              style: GoogleFonts.inter(
                fontSize: Responsive.scaledFontSize(context, 15.5),
                fontWeight: FontWeight.w900,
                color: AppDesignSystem.slate900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isLive
                  ? 'New customer orders placed in Ghatampur will appear here automatically every 3 seconds.'
                  : 'Delivered and past completed orders will be archived here.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: Responsive.scaledFontSize(context, 12),
                color: AppDesignSystem.slate500,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: () {
                HapticFeedback.lightImpact();
                onRefresh();
              },
              icon: const Icon(Icons.sync_rounded, size: 16, color: Colors.white),
              label: Text(
                'Check Database / Refresh',
                style: GoogleFonts.inter(
                  fontSize: Responsive.scaledFontSize(context, 12),
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: isLive ? primaryRed : AppDesignSystem.slate900,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
