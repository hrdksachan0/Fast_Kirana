import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/design_system.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppDesignSystem.background,
      appBar: AppBar(
        backgroundColor: AppDesignSystem.background,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'About Us',
          style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 18), fontWeight: FontWeight.w800, color: AppDesignSystem.textPrimary),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Logo
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppDesignSystem.primary, AppDesignSystem.primaryDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: AppDesignSystem.shadowGlow,
              ),
              child: const Icon(Icons.shopping_basket_rounded, size: 50, color: Colors.white),
            ),

            const SizedBox(height: 16),
            Text(
              'FastKirana',
              style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 24), fontWeight: FontWeight.w800, color: AppDesignSystem.textPrimary),
            ),
            Text(
              'v1.0.0',
              style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 13), color: AppDesignSystem.textSecondary),
            ),

            const SizedBox(height: 24),

            // Description
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppDesignSystem.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppDesignSystem.borderLight),
                boxShadow: AppDesignSystem.shadowSm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Our Story', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 16), fontWeight: FontWeight.w800, color: AppDesignSystem.textPrimary)),
                  const SizedBox(height: 12),
                  Text(
                    'FastKirana brings the local kirana store to your fingertips. We deliver fresh groceries, daily essentials, and cafe delights fast — from farm to your home, we ensure quality and freshness at the best prices.',
                    style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 13), color: AppDesignSystem.textSecondary, height: 1.6),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Stats
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppDesignSystem.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppDesignSystem.borderLight),
                boxShadow: AppDesignSystem.shadowSm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Our Reach', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 16), fontWeight: FontWeight.w800, color: AppDesignSystem.textPrimary)),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _statBox(context, '50K+', 'Happy Users'),
                      _statBox(context, '500+', 'Products'),
                      _statBox(context, '30 min', 'Delivery'),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Legal
            Container(
              decoration: BoxDecoration(
                color: AppDesignSystem.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppDesignSystem.borderLight),
              ),
              child: Column(
                children: [
                  _linkItem(context, 'Privacy Policy'),
                  _divider(),
                  _linkItem(context, 'Terms of Service'),
                  _divider(),
                  _linkItem(context, 'Refund Policy'),
                  _divider(),
                  _linkItem(context, 'Rate Us on Play Store'),
                ],
              ),
            ),

            const SizedBox(height: 24),
            Text(
              'Made with ❤️ in India',
              style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 12), color: AppDesignSystem.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statBox(BuildContext context, String number, String label) {
    return Column(
      children: [
        Text(number, style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 20), fontWeight: FontWeight.w800, color: AppDesignSystem.primary)),
        const SizedBox(height: 4),
        Text(label, style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 12), color: AppDesignSystem.textSecondary)),
      ],
    );
  }

  Widget _linkItem(BuildContext context, String label) {
    return ListTile(
      title: Text(label, style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 14), color: AppDesignSystem.textPrimary)),
      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppDesignSystem.textMuted),
      onTap: () {},
    );
  }

  Widget _divider() {
    return const Divider(height: 1, indent: 16, endIndent: 16, color: AppDesignSystem.divider);
  }
}