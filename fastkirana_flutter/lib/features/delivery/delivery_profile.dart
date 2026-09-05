import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/design_system.dart';

class DeliveryProfileScreen extends StatelessWidget {
  const DeliveryProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppDesignSystem.background,
      appBar: AppBar(
        backgroundColor: AppDesignSystem.background,
        elevation: 0,
        title: Text('Profile', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 18), fontWeight: FontWeight.w800, color: AppDesignSystem.textPrimary)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppDesignSystem.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppDesignSystem.borderLight),
                boxShadow: AppDesignSystem.shadowSm,
              ),
              child: Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(gradient: const LinearGradient(colors: [AppDesignSystem.primary, AppDesignSystem.primaryDark]), borderRadius: BorderRadius.circular(30)),
                    child: Center(child: Text('RK', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 18), fontWeight: FontWeight.w800, color: Colors.white))),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Ravi Kumar', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 16), fontWeight: FontWeight.w800, color: AppDesignSystem.textPrimary)),
                        Text('+91 98xxx xxx00', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 13), color: AppDesignSystem.textSecondary)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.star_rounded, color: AppDesignSystem.warning, size: 14),
                            const SizedBox(width: 4),
                            Text('4.8 rating', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 12), color: AppDesignSystem.textSecondary)),
                            const SizedBox(width: 12),
                            Text('142 orders', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 12), color: AppDesignSystem.textSecondary)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(color: AppDesignSystem.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppDesignSystem.borderLight), boxShadow: AppDesignSystem.shadowSm),
              child: Column(
                children: [
                  _menuTile(context, 'Vehicle Info', 'Bike • DL 1C XX00', Icons.directions_bike_rounded),
                  _divider(),
                  _menuTile(context, 'Documents', '2/3 verified', Icons.document_scanner_rounded),
                  _divider(),
                  _menuTile(context, 'Bank Account', 'HDFC • xxxx 1234', Icons.account_balance_rounded),
                  _divider(),
                  _menuTile(context, 'Notifications', '', Icons.notifications_none_rounded),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _menuTile(BuildContext context, String title, String subtitle, IconData icon) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: AppDesignSystem.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: AppDesignSystem.primary, size: 18),
      ),
      title: Text(title, style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 14), fontWeight: FontWeight.w700, color: AppDesignSystem.textPrimary)),
      subtitle: subtitle.isNotEmpty ? Text(subtitle, style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 12), color: AppDesignSystem.textSecondary)) : null,
      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppDesignSystem.textMuted),
    );
  }

  Widget _divider() {
    return const Divider(height: 1, indent: 56, endIndent: 16, color: AppDesignSystem.divider);
  }
}