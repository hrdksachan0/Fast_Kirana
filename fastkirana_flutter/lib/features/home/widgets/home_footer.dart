import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fastkirana_flutter/core/theme/design_system.dart';

class HomeFooter extends StatelessWidget {
  const HomeFooter({super.key});

  Widget _buildPaymentIcon(BuildContext context, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusSm),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: Responsive.scaledFontSize(context, 9.5),
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppDesignSystem.radiusLg),
          border: Border.all(color: AppDesignSystem.borderLight),
        ),
        child: Column(
          children: [
            Text(
              '© 2026 FastKirana. All rights reserved.',
              style: GoogleFonts.inter(
                fontSize: Responsive.scaledFontSize(context, 11),
                color: AppDesignSystem.textMuted,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildPaymentIcon(context, 'UPI', AppDesignSystem.amber600),
                const SizedBox(width: 12),
                _buildPaymentIcon(context, 'Card', AppDesignSystem.lime500),
                const SizedBox(width: 12),
                _buildPaymentIcon(context, 'COD', AppDesignSystem.primary),
                const SizedBox(width: 12),
                _buildPaymentIcon(context, 'Wallet', AppDesignSystem.info),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '+91 81128 49854 | fastkiranadelivery@gmail.com',
              style: GoogleFonts.inter(
                fontSize: Responsive.scaledFontSize(context, 10.5),
                fontWeight: FontWeight.w600,
                color: AppDesignSystem.textSecondary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '7 AM – 10 PM | NH34, Ghatampur, Kanpur Nagar',
              style: GoogleFonts.inter(
                fontSize: Responsive.scaledFontSize(context, 9.5),
                color: AppDesignSystem.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
