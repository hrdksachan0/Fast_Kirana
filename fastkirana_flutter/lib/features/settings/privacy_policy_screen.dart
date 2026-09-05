import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/design_system.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  static const _effectiveDate = '2026-01-01';
  static const _supportEmail = 'fastkiranadelivery@gmail.com';
  static const _supportPhone = '+91 81128 49854';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppDesignSystem.background,
      appBar: AppBar(
        backgroundColor: AppDesignSystem.background,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Privacy Policy',
          style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 18), fontWeight: FontWeight.w800, color: AppDesignSystem.textPrimary),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCard(
              context,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'FastKirana — Privacy Policy',
                    style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 20), fontWeight: FontWeight.w800, color: AppDesignSystem.textPrimary),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Effective Date: $_effectiveDate',
                    style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 13), color: AppDesignSystem.textSecondary),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            _buildSection(context, '1. Information We Collect'),
            _buildParagraph(
              context,
              'We collect information you provide directly to us, such as when you create an account, '
              'place an order, or contact support. This includes:',
            ),
            _bullet(context, 'Name, phone number, and email address'),
            _bullet(context, 'Delivery address and location data'),
            _bullet(context, 'Order history and payment information'),
            _bullet(context, 'Device information and app usage data'),

            const SizedBox(height: 16),
            _buildSection(context, '2. How We Use Your Information'),
            _buildParagraph(
              context,
              'We use the information we collect to process orders, improve our services, '
              'send order updates and notifications, provide customer support, and ensure the security of our platform.',
            ),

            const SizedBox(height: 16),
            _buildSection(context, '3. Location Data'),
            _buildParagraph(
              context,
              'FastKirana requires location access to provide delivery services. '
              'Your location is used only to calculate delivery fees, find nearby products, '
              'and assign delivery partners. We do not store your location data beyond what is necessary for active orders.',
            ),

            const SizedBox(height: 16),
            _buildSection(context, '4. Data Sharing'),
            _buildParagraph(
              context,
              'We share your data only with:',
            ),
            _bullet(context, 'Delivery partners (name, phone, address for delivery)'),
            _bullet(context, 'Payment processors (for transaction processing)'),
            _bullet(context, 'Cloud service providers (for app hosting and notifications)'),
            _buildParagraph(context, 'We never sell your personal data to third parties.'),

            const SizedBox(height: 16),
            _buildSection(context, '5. Notifications'),
            _buildParagraph(
              context,
              'We use Firebase Cloud Messaging (FCM) to send order updates, delivery alerts, '
              'and promotional offers. You can manage notification preferences in the app Settings.',
            ),

            const SizedBox(height: 16),
            _buildSection(context, '6. Data Security'),
            _buildParagraph(
              context,
              'We implement industry-standard security measures to protect your personal information. '
              'All data is transmitted over encrypted connections (HTTPS).',
            ),

            const SizedBox(height: 16),
            _buildSection(context, '7. Your Rights'),
            _buildParagraph(
              context,
              'You have the right to access, correct, or delete your personal data. '
              'Contact us at $_supportEmail or $_supportPhone for any data-related requests.',
            ),

            const SizedBox(height: 16),
            _buildSection(context, '8. Changes to This Policy'),
            _buildParagraph(
              context,
              'We may update this privacy policy from time to time. Changes will be posted in the app and on our website.',
            ),

            const SizedBox(height: 24),

            Center(
              child: TextButton.icon(
                onPressed: () => _launchSupport(context),
                icon: const Icon(Icons.email_outlined, size: 18, color: AppDesignSystem.primary),
                label: Text(
                  'Contact us: $_supportEmail',
                  style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 14), color: AppDesignSystem.primary, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(BuildContext context, String title) {
    return Text(
      title,
      style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 16), fontWeight: FontWeight.w700, color: AppDesignSystem.textPrimary),
    );
  }

  Widget _buildParagraph(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        text,
        style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 14), color: AppDesignSystem.textSecondary, height: 1.7),
      ),
    );
  }

  Widget _bullet(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('• ', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 14), color: AppDesignSystem.textSecondary, height: 1.7)),
          Expanded(
            child: Text(text, style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 14), color: AppDesignSystem.textSecondary, height: 1.7)),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(BuildContext context, {required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppDesignSystem.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppDesignSystem.borderLight),
      ),
      child: child,
    );
  }

  Future<void> _launchSupport(BuildContext context) async {
    final uri = Uri(scheme: 'mailto', path: _supportEmail, query: 'subject=Privacy Policy Query - FastKirana');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Email us at $_supportEmail'), backgroundColor: AppDesignSystem.primary),
        );
      }
    }
  }
}
