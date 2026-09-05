import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/design_system.dart';
import 'privacy_policy_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppDesignSystem.background,
      appBar: AppBar(
        backgroundColor: AppDesignSystem.background,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Settings',
          style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 18), fontWeight: FontWeight.w800, color: AppDesignSystem.textPrimary),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Notifications
            _sectionHeader(context, 'Notifications'),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: AppDesignSystem.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppDesignSystem.borderLight),
                boxShadow: AppDesignSystem.shadowSm,
              ),
              child: Column(
                children: [
                  _switchTile(context, 'Push Notifications', 'Receive order updates', true, (v) {}),
                  _divider(),
                  _switchTile(context, 'Email Notifications', 'Offers and newsletters', false, (v) {}),
                  _divider(),
                  _switchTile(context, 'SMS Alerts', 'Delivery updates via SMS', true, (v) {}),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Preferences
            _sectionHeader(context, 'Preferences'),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: AppDesignSystem.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppDesignSystem.borderLight),
                boxShadow: AppDesignSystem.shadowSm,
              ),
              child: Column(
                children: [
                  _navTile(context, Icons.language_rounded, 'Language', 'English', () {}),
                  _divider(),
                  _navTile(context, Icons.location_on_rounded, 'Location', 'Ghatampur, Kanpur', () {}),
                  _divider(),
                  _switchTile(context, 'Dark Mode', 'Switch to dark theme', false, (v) {}),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Account
            _sectionHeader(context, 'Account'),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: AppDesignSystem.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppDesignSystem.borderLight),
                boxShadow: AppDesignSystem.shadowSm,
              ),
              child: Column(
                children: [
                  _navTile(context, Icons.person_rounded, 'Edit Profile', '', () {}),
                  _divider(),
                  _navTile(context, Icons.lock_rounded, 'Change Password', '', () {}),
                  _divider(),
                  _navTile(context, Icons.delete_outline_rounded, 'Delete Account', '', () {}, isDanger: true),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Legal
            _sectionHeader(context, 'Legal'),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: AppDesignSystem.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppDesignSystem.borderLight),
                boxShadow: AppDesignSystem.shadowSm,
              ),
              child: Column(
                children: [
                  _navTile(context, Icons.privacy_tip_rounded, 'Privacy Policy', 'How we handle your data', () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()));
                  }),
                  _divider(),
                  _navTile(context, Icons.description_rounded, 'Terms & Conditions', 'Usage terms', () {}),
                  _divider(),
                  _navTile(context, Icons.info_outline_rounded, 'About', 'FastKirana v1.0.0', () {}),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Logout
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppDesignSystem.danger.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppDesignSystem.danger.withValues(alpha: 0.15)),
              ),
              child: TextButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.logout_rounded, color: AppDesignSystem.danger),
                label: Text('Logout', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 15), fontWeight: FontWeight.w700, color: AppDesignSystem.danger)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(BuildContext context, String title) {
    return Text(title, style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 14), fontWeight: FontWeight.w800, color: AppDesignSystem.textSecondary));
  }

  Widget _switchTile(BuildContext context, String title, String subtitle, bool value, Function(bool) onChanged) {
    return SwitchListTile(
      title: Text(title, style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 14), fontWeight: FontWeight.w600, color: AppDesignSystem.textPrimary)),
      subtitle: Text(subtitle, style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 12), color: AppDesignSystem.textSecondary)),
      value: value,
      onChanged: (v) => onChanged(v),
      activeColor: AppDesignSystem.primary,
    );
  }

  Widget _navTile(BuildContext context, IconData icon, String title, String subtitle, VoidCallback onTap, {bool isDanger = false}) {
    return ListTile(
      leading: Icon(icon, size: 22, color: isDanger ? AppDesignSystem.danger : AppDesignSystem.primary),
      title: Text(title, style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 14), fontWeight: FontWeight.w600, color: isDanger ? AppDesignSystem.danger : AppDesignSystem.textPrimary)),
      subtitle: subtitle.isNotEmpty ? Text(subtitle, style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 12), color: AppDesignSystem.textSecondary)) : null,
      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppDesignSystem.textMuted),
      onTap: onTap,
    );
  }

  Widget _divider() {
    return const Divider(height: 1, indent: 56, endIndent: 16, color: AppDesignSystem.divider);
  }
}