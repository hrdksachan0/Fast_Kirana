import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/design_system.dart';
import '../../providers/referral_provider.dart';

class ReferralScreen extends ConsumerWidget {
  const ReferralScreen({super.key});

  Future<void> _shareOnWhatsApp(BuildContext context, String text) async {
    final encoded = Uri.encodeComponent(text);
    final uri = Uri.parse('whatsapp://send?text=$encoded');
    final webUri = Uri.parse('https://api.whatsapp.com/send?text=$encoded');

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else if (await canLaunchUrl(webUri)) {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      } else {
        await Clipboard.setData(ClipboardData(text: text));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('WhatsApp not found. Invite text copied to clipboard!')),
          );
        }
      }
    } catch (e) {
      await Clipboard.setData(ClipboardData(text: text));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invite text copied to clipboard!')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final infoAsync = ref.watch(referralInfoProvider);
    final statsAsync = ref.watch(referralStatsProvider);

    return Scaffold(
      backgroundColor: AppDesignSystem.background,
      appBar: AppBar(
        backgroundColor: AppDesignSystem.background,
        elevation: 0,
        title: Text(
          'Refer & Earn',
          style: GoogleFonts.inter(
            fontSize: Responsive.scaledFontSize(context, 18),
            fontWeight: FontWeight.w800,
            color: AppDesignSystem.textPrimary,
          ),
        ),
      ),
      body: infoAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error loading referral info: $err')),
        data: (info) {
          if (info == null) {
            return const Center(child: Text('Referral program currently unavailable'));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Hero Gift Card
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0F9D58), Color(0xFF0B8043)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: AppDesignSystem.shadowCard,
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.celebration_rounded, color: Colors.white, size: 48),
                      const SizedBox(height: 12),
                      Text(
                        'Earn ₹${info.referrerReward.toInt()} Free Grocery!',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 22),
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Invite a friend. They get ₹${info.refereeDiscount.toInt()} OFF on their 1st order. When their order is delivered, you get ₹${info.referrerReward.toInt()} directly in your Fastkirana Wallet!',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 12),
                          color: Colors.white.withValues(alpha: 0.9),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Referral Code Box
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    color: AppDesignSystem.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppDesignSystem.borderLight, width: 1.5),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'YOUR REFERRAL CODE',
                              style: GoogleFonts.inter(
                                fontSize: Responsive.scaledFontSize(context, 10),
                                fontWeight: FontWeight.w800,
                                color: AppDesignSystem.textSecondary,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              info.referralCode,
                              style: GoogleFonts.inter(
                                fontSize: Responsive.scaledFontSize(context, 22),
                                fontWeight: FontWeight.w900,
                                color: AppDesignSystem.primary,
                                letterSpacing: 2,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppDesignSystem.primary.withValues(alpha: 0.1),
                          foregroundColor: AppDesignSystem.primary,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        ),
                        icon: const Icon(Icons.copy_rounded, size: 16),
                        label: const Text('Copy'),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: info.referralCode));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Referral code copied to clipboard!')),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // WhatsApp Share Button
                SizedBox(
                  height: 54,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    icon: const Icon(Icons.share_rounded, size: 20),
                    label: Text(
                      'Share on WhatsApp',
                      style: GoogleFonts.inter(
                        fontSize: Responsive.scaledFontSize(context, 16),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    onPressed: () => _shareOnWhatsApp(context, info.whatsappShareText),
                  ),
                ),
                const SizedBox(height: 24),

                // Live Stats Section
                statsAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (stats) {
                    if (stats == null) return const SizedBox.shrink();

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Your Referrals Summary',
                          style: GoogleFonts.inter(
                            fontSize: Responsive.scaledFontSize(context, 16),
                            fontWeight: FontWeight.w800,
                            color: AppDesignSystem.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _statCard(
                                context,
                                'Friends Joined',
                                stats.totalInvited.toString(),
                                Icons.people_alt_rounded,
                                const Color(0xFF1A73E8),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _statCard(
                                context,
                                'Cash Earned',
                                '₹${stats.totalEarned.toInt()}',
                                Icons.account_balance_wallet_rounded,
                                const Color(0xFF0F9D58),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Recent Friends List
                        if (stats.recentReferrals.isNotEmpty) ...[
                          Text(
                            'Invited Friends',
                            style: GoogleFonts.inter(
                              fontSize: Responsive.scaledFontSize(context, 14),
                              fontWeight: FontWeight.w700,
                              color: AppDesignSystem.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...stats.recentReferrals.map((r) {
                            final isDone = r['status'] == 'COMPLETED';
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppDesignSystem.surface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppDesignSystem.borderLight),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor: (isDone ? AppDesignSystem.success : AppDesignSystem.warning).withValues(alpha: 0.15),
                                    child: Icon(
                                      isDone ? Icons.check_circle_rounded : Icons.hourglass_top_rounded,
                                      size: 18,
                                      color: isDone ? AppDesignSystem.success : AppDesignSystem.warning,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          r['friendName'] ?? 'Friend',
                                          style: GoogleFonts.inter(
                                            fontSize: Responsive.scaledFontSize(context, 13),
                                            fontWeight: FontWeight.w700,
                                            color: AppDesignSystem.textPrimary,
                                          ),
                                        ),
                                        Text(
                                          isDone ? 'First order delivered! Reward credited.' : 'Waiting for 1st order delivery',
                                          style: GoogleFonts.inter(
                                            fontSize: Responsive.scaledFontSize(context, 11),
                                            color: AppDesignSystem.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (isDone)
                                    Text(
                                      '+₹${(r['reward'] as num?)?.toInt() ?? 100}',
                                      style: GoogleFonts.inter(
                                        fontSize: Responsive.scaledFontSize(context, 14),
                                        fontWeight: FontWeight.w800,
                                        color: AppDesignSystem.success,
                                      ),
                                    ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ],
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _statCard(BuildContext context, String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppDesignSystem.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppDesignSystem.borderLight),
        boxShadow: AppDesignSystem.shadowSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: color.withValues(alpha: 0.1),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: Responsive.scaledFontSize(context, 20),
              fontWeight: FontWeight.w900,
              color: AppDesignSystem.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: Responsive.scaledFontSize(context, 11),
              color: AppDesignSystem.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
