import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_bounceable/flutter_bounceable.dart';

import '../../../core/theme/design_system.dart';
import '../../../core/services/battery_optimization_service.dart';

class BatteryOptimizationDialog extends StatelessWidget {
  final VoidCallback? onDismissed;

  const BatteryOptimizationDialog({super.key, this.onDismissed});

  static Future<void> showIfNecessary(BuildContext context) async {
    final shouldShow = await BatteryOptimizationService.shouldShowPrompt();
    if (!shouldShow || !context.mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const BatteryOptimizationDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Icon & Title
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    color: AppDesignSystem.amber50,
                    borderRadius: BorderRadius.all(Radius.circular(16)),
                    border: Border.fromBorderSide(BorderSide(color: AppDesignSystem.amber400, width: 1.5)),
                  ),
                  child: const Center(
                    child: Icon(Icons.battery_alert_rounded, color: AppDesignSystem.amber700, size: 28),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Don’t Miss Orders! 🔔',
                        style: GoogleFonts.inter(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: AppDesignSystem.slate900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Keep Kitchen / Alert Chime Active',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppDesignSystem.slate500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Hinglish Explanatory Card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppDesignSystem.slate50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppDesignSystem.slate200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Jab phone locked ya pocket me ho, tab bhi order sound bajaane ke liye 2 settings zaroori hain:',
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: AppDesignSystem.slate800,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildStepRow('1', 'Battery Optimization: "Don\'t optimize" / "Unrestricted" karein.'),
                  const SizedBox(height: 8),
                  _buildStepRow('2', 'Autostart: (Xiaomi, Vivo, Oppo) FastKirana ko Allow karein.'),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppDesignSystem.slate300),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                    onPressed: () async {
                      HapticFeedback.lightImpact();
                      await BatteryOptimizationService.markDismissed(permanent: false);
                      if (context.mounted) Navigator.pop(context);
                      onDismissed?.call();
                    },
                    child: Text(
                      'Later',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700,
                        color: AppDesignSystem.slate600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: Bounceable(
                    onTap: () async {
                      HapticFeedback.heavyImpact();
                      await BatteryOptimizationService.requestExemption();
                      await BatteryOptimizationService.markDismissed(permanent: true);
                      if (context.mounted) Navigator.pop(context);
                      onDismissed?.call();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      decoration: BoxDecoration(
                        color: AppDesignSystem.primary,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: AppDesignSystem.primary.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          'Enable Now ⚡',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            fontSize: 13.5,
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

  Widget _buildStepRow(String number, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: const BoxDecoration(
            color: AppDesignSystem.emerald600,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppDesignSystem.slate700,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}
