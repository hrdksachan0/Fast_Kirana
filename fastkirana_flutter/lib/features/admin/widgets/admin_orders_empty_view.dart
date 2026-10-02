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
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxHeight < 250;
        return Center(
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            padding: EdgeInsets.symmetric(
              horizontal: 20,
              vertical: isCompact ? 10 : 24,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: isCompact ? 46 : 64,
                  height: isCompact ? 46 : 64,
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
                      size: isCompact ? 22 : 32,
                      color: isLive ? primaryRed : AppDesignSystem.slate500,
                    ),
                  ),
                ),
                SizedBox(height: isCompact ? 8 : 14),
                Text(
                  isLive ? 'No Active Live Orders' : 'No Order History Yet',
                  style: GoogleFonts.inter(
                    fontSize: Responsive.scaledFontSize(context, isCompact ? 14 : 15.5),
                    fontWeight: FontWeight.w900,
                    color: AppDesignSystem.slate900,
                  ),
                ),
                const SizedBox(height: 4),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 320),
                  child: Text(
                    isLive
                        ? 'New customer orders placed in Ghatampur will appear here automatically every 3 seconds.'
                        : 'Delivered and past completed orders will be archived here.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: Responsive.scaledFontSize(context, isCompact ? 11 : 12),
                      color: AppDesignSystem.slate500,
                      height: 1.35,
                    ),
                  ),
                ),
                SizedBox(height: isCompact ? 10 : 16),
                ElevatedButton.icon(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    onRefresh();
                  },
                  icon: const Icon(Icons.sync_rounded, size: 15, color: Colors.white),
                  label: Text(
                    'Check Database / Refresh',
                    style: GoogleFonts.inter(
                      fontSize: Responsive.scaledFontSize(context, isCompact ? 11 : 12),
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isLive ? primaryRed : AppDesignSystem.slate900,
                    padding: EdgeInsets.symmetric(
                      horizontal: isCompact ? 14 : 18,
                      vertical: isCompact ? 7 : 10,
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
