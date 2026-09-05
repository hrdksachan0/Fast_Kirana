import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/design_system.dart';

class AdminSettingsScreen extends StatelessWidget {
  const AdminSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppDesignSystem.background,
      appBar: AppBar(
        backgroundColor: AppDesignSystem.background,
        elevation: 0,
        title: Text('Settings', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 18), fontWeight: FontWeight.w800, color: AppDesignSystem.textPrimary)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Delivery Settings
            Text('Delivery Settings', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 12), fontWeight: FontWeight.w800, color: AppDesignSystem.textSecondary, letterSpacing: 0.5)),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(color: AppDesignSystem.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppDesignSystem.borderLight), boxShadow: AppDesignSystem.shadowSm),
              child: Column(
                children: [
                  _switchTile(context, 'Auto-assign orders', 'Assign orders to nearest delivery boy', true, (v) {}),
                  _divider(),
                  _switchTile(context, 'Live tracking', 'Enable real-time order tracking', true, (v) {}),
                  _divider(),
                  _switchTile(context, 'Cash on Delivery', 'Accept COD orders', true, (v) {}),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text('Notifications', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 12), fontWeight: FontWeight.w800, color: AppDesignSystem.textSecondary, letterSpacing: 0.5)),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(color: AppDesignSystem.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppDesignSystem.borderLight), boxShadow: AppDesignSystem.shadowSm),
              child: Column(
                children: [
                  _switchTile(context, 'New order alerts', 'Notify when new order arrives', true, (v) {}),
                  _divider(),
                  _switchTile(context, 'Daily reports', 'Send daily sales summary', false, (v) {}),
                  _divider(),
                  _switchTile(context, 'Low stock alerts', 'Notify when stock < 10', true, (v) {}),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppDesignSystem.danger.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppDesignSystem.danger.withValues(alpha: 0.15)),
              ),
              child: TextButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.logout_rounded, color: AppDesignSystem.danger),
                label: Text('Logout Admin', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 15), fontWeight: FontWeight.w700, color: AppDesignSystem.danger)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _switchTile(BuildContext context, String title, String subtitle, bool value, Function(bool) onChanged) {
    return SwitchListTile(
      value: value,
      onChanged: (v) => onChanged(v),
      activeColor: AppDesignSystem.primary,
      title: Text(title, style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 14), fontWeight: FontWeight.w700, color: AppDesignSystem.textPrimary)),
      subtitle: Text(subtitle, style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 12), color: AppDesignSystem.textSecondary)),
    );
  }

  Widget _divider() {
    return const Divider(height: 1, indent: 16, endIndent: 16, color: AppDesignSystem.divider);
  }
}