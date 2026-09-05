import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/design_system.dart';
import '../../providers/auth_provider.dart';

class ReferEarnScreen extends ConsumerWidget {
  const ReferEarnScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).value;
    final phone = user?.phone?.replaceAll('+91', '').replaceAll(' ', '').trim() ?? '';
    final referralCode = phone.length >= 4
        ? 'FK${phone.substring(phone.length - 4)}'
        : (user?.id.isNotEmpty == true && user!.id.length >= 4 ? 'FK${user.id.substring(user.id.length - 4).toUpperCase()}' : 'FASTKIRANA');

    return Scaffold(
      backgroundColor: AppDesignSystem.background,
      appBar: AppBar(
        backgroundColor: AppDesignSystem.background,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Refer & Earn',
          style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 18), fontWeight: FontWeight.w800, color: AppDesignSystem.textPrimary),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Hero Card
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppDesignSystem.primary, AppDesignSystem.primaryDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: AppDesignSystem.shadowCard,
              ),
              child: Column(
                children: [
                  Text(
                    'Your Referral Code',
                    style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 14), color: Colors.white.withValues(alpha: 0.9)),
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: referralCode));
                      HapticFeedback.lightImpact();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Copied "$referralCode" to clipboard!'),
                          backgroundColor: AppDesignSystem.green700,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            referralCode,
                            style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 24), fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 2),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.copy_rounded, size: 16, color: Colors.white),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Share with friends & earn rewards!',
                    style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 15), color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // How it works
            Text(
              'How it works',
              style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 18), fontWeight: FontWeight.w800, color: AppDesignSystem.textPrimary),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _stepCard(context, '1', 'Share Code', 'Send your referral code to friends'),
                _stepCard(context, '2', 'They Sign Up', 'Friend uses your code & first order'),
                _stepCard(context, '3', 'You Earn', 'Get ₹50 in your wallet'),
              ],
            ),

            const SizedBox(height: 24),

            // Stats
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppDesignSystem.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppDesignSystem.borderLight),
                boxShadow: AppDesignSystem.shadowSm,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _statItem(context, 'Total Referrals', '12'),
                  _statItem(context, 'Successful', '8'),
                  _statItem(context, 'Earned', '₹400'),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Share buttons
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppDesignSystem.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.share_rounded, color: Colors.white),
                label: Text('Share Referral Code', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 16), fontWeight: FontWeight.w800, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stepCard(BuildContext context, String number, String title, String desc) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppDesignSystem.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppDesignSystem.borderLight),
          boxShadow: AppDesignSystem.shadowSm,
        ),
        child: Column(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [AppDesignSystem.primary, AppDesignSystem.primaryDark]),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Text(number, style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 14), fontWeight: FontWeight.w800, color: Colors.white)),
              ),
            ),
            const SizedBox(height: 8),
            Text(title, style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 13), fontWeight: FontWeight.w700, color: AppDesignSystem.textPrimary), textAlign: TextAlign.center),
            const SizedBox(height: 4),
            Text(desc, style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 11), color: AppDesignSystem.textSecondary), textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  Widget _statItem(BuildContext context, String label, String value) {
    return Column(
      children: [
        Text(value, style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 20), fontWeight: FontWeight.w800, color: AppDesignSystem.primary)),
        const SizedBox(height: 4),
        Text(label, style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 12), color: AppDesignSystem.textSecondary)),
      ],
    );
  }
}