import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/design_system.dart';
import '../../providers/referral_provider.dart';

class ReferralScreen extends ConsumerStatefulWidget {
  const ReferralScreen({super.key});

  @override
  ConsumerState<ReferralScreen> createState() => _ReferralScreenState();
}

class _ReferralScreenState extends ConsumerState<ReferralScreen> {
  final TextEditingController _codeController = TextEditingController();
  bool _isApplying = false;
  String? _applySuccessMessage;
  String? _applyErrorMessage;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _handleApplyCode() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      setState(() {
        _applyErrorMessage = 'Please enter a referral code';
        _applySuccessMessage = null;
      });
      return;
    }

    setState(() {
      _isApplying = true;
      _applyErrorMessage = null;
      _applySuccessMessage = null;
    });

    FocusScope.of(context).unfocus();
    final result = await applyReferralCode(ref, code);

    if (!mounted) return;

    setState(() {
      _isApplying = false;
      if (result.success) {
        _applySuccessMessage = result.message;
        _applyErrorMessage = null;
        _codeController.clear();
      } else {
        _applyErrorMessage = result.message;
        _applySuccessMessage = null;
      }
    });

    HapticFeedback.mediumImpact();
  }

  Future<void> _shareOnWhatsApp(BuildContext context, String text) async {
    HapticFeedback.lightImpact();
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
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: text));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invite text copied to clipboard!')),
        );
      }
    }
  }

  Future<void> _shareMore(String text) async {
    HapticFeedback.lightImpact();
    try {
      await Share.share(
        text,
        subject: 'FastMinute Grocery Referral: Get ₹50 OFF!',
      );
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: text));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invite text copied to clipboard!')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final infoAsync = ref.watch(referralInfoProvider);
    final statsAsync = ref.watch(referralStatsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), // Ultra-clean executive slate 50
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          tooltip: 'Back',
          icon: Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppDesignSystem.slate200),
              boxShadow: AppDesignSystem.shadowSm,
            ),
            child: const Icon(Icons.arrow_back_rounded, size: 18, color: AppDesignSystem.slate900),
          ),
          onPressed: () {
            HapticFeedback.lightImpact();
            Navigator.maybePop(context);
          },
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Refer & Earn',
              style: GoogleFonts.inter(
                fontSize: Responsive.scaledFontSize(context, 18),
                fontWeight: FontWeight.w800,
                color: AppDesignSystem.slate900,
                letterSpacing: -0.3,
              ),
            ),
            Text(
              'Give ₹50, Get ₹100 Free Grocery Cash',
              style: GoogleFonts.inter(
                fontSize: Responsive.scaledFontSize(context, 11),
                color: AppDesignSystem.slate500,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
      body: infoAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppDesignSystem.primary),
        ),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Unable to load referral program: $err',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: AppDesignSystem.slate500),
            ),
          ),
        ),
        data: (info) {
          if (info == null) {
            return Center(
              child: Text(
                'Referral program currently unavailable',
                style: GoogleFonts.inter(color: AppDesignSystem.slate600, fontWeight: FontWeight.w600),
              ),
            );
          }

          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Executive Emerald Hero Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF064E3B), Color(0xFF059669)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF059669).withValues(alpha: 0.25),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Floating Frosted Chip
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('🎁', style: TextStyle(fontSize: 12)),
                            const SizedBox(width: 5),
                            Text(
                              'EXCLUSIVE INVITE BONUS',
                              style: GoogleFonts.inter(
                                fontSize: Responsive.scaledFontSize(context, 10),
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Earn ₹${info.referrerReward.toInt()} Free Grocery!',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 22),
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Invite your friends & family. They get ₹${info.refereeDiscount.toInt()} OFF on their 1st order. When delivered, ₹${info.referrerReward.toInt()} is added to your Wallet instantly!',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 12),
                          color: Colors.white.withValues(alpha: 0.92),
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 3-Step Flow Pills
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            _buildStepBadge(context, '1', 'Share\nCode', Icons.share_rounded),
                            _buildArrow(),
                            _buildStepBadge(context, '2', 'Friend\nGets ₹50', Icons.discount_rounded),
                            _buildArrow(),
                            _buildStepBadge(context, '3', 'You Get\n₹100 Cash', Icons.account_balance_wallet_rounded),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // 2. Voucher Ticket Referral Code Card
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppDesignSystem.slate200),
                    boxShadow: AppDesignSystem.shadowSm,
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFA7F3D0)),
                        ),
                        child: const Icon(Icons.confirmation_number_rounded, color: Color(0xFF059669), size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'YOUR REFERRAL CODE',
                              style: GoogleFonts.inter(
                                fontSize: Responsive.scaledFontSize(context, 10),
                                fontWeight: FontWeight.w800,
                                color: AppDesignSystem.slate400,
                                letterSpacing: 1.1,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              info.referralCode,
                              style: GoogleFonts.inter(
                                fontSize: Responsive.scaledFontSize(context, 20),
                                fontWeight: FontWeight.w900,
                                color: AppDesignSystem.slate900,
                                letterSpacing: 2,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF059669),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        ),
                        icon: const Icon(Icons.copy_rounded, size: 15),
                        label: Text(
                          'Copy',
                          style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w800),
                        ),
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          Clipboard.setData(ClipboardData(text: info.referralCode));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: AppDesignSystem.slate900,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              content: Text(
                                'Referral code "${info.referralCode}" copied to clipboard!',
                                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // 3. Sharing Action Buttons (WhatsApp + More Options)
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: SizedBox(
                        height: 50,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF25D366), // Official WhatsApp Green
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          icon: const Icon(Icons.share_rounded, size: 18),
                          label: Text(
                            'Share on WhatsApp',
                            style: GoogleFonts.inter(
                              fontSize: Responsive.scaledFontSize(context, 14),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          onPressed: () => _shareOnWhatsApp(context, info.whatsappShareText),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: SizedBox(
                        height: 50,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: AppDesignSystem.slate800,
                            side: const BorderSide(color: AppDesignSystem.slate200),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          icon: const Icon(Icons.more_horiz_rounded, size: 18),
                          label: Text(
                            'More',
                            style: GoogleFonts.inter(
                              fontSize: Responsive.scaledFontSize(context, 13.5),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          onPressed: () => _shareMore(info.whatsappShareText),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // 4. "Have a Referral Code?" Redeem Input Box
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppDesignSystem.slate200),
                    boxShadow: AppDesignSystem.shadowSm,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.card_giftcard_rounded, size: 18, color: Color(0xFF059669)),
                          const SizedBox(width: 8),
                          Text(
                            'Have a Friend\'s Referral Code?',
                            style: GoogleFonts.inter(
                              fontSize: Responsive.scaledFontSize(context, 13.5),
                              fontWeight: FontWeight.w800,
                              color: AppDesignSystem.slate900,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Apply their code to get ₹50 OFF on your first grocery order',
                        style: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 11),
                          color: AppDesignSystem.slate500,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 46,
                              child: TextField(
                                controller: _codeController,
                                textCapitalization: TextCapitalization.characters,
                                style: GoogleFonts.inter(
                                  fontSize: Responsive.scaledFontSize(context, 14),
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.5,
                                  color: AppDesignSystem.slate900,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Enter code (e.g. FAST1234)',
                                  hintStyle: GoogleFonts.inter(
                                    fontSize: Responsive.scaledFontSize(context, 12),
                                    fontWeight: FontWeight.w500,
                                    letterSpacing: 0,
                                    color: AppDesignSystem.slate400,
                                  ),
                                  filled: true,
                                  fillColor: const Color(0xFFF8FAFC),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(color: AppDesignSystem.slate200),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(color: AppDesignSystem.slate200),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(color: Color(0xFF059669), width: 1.5),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          SizedBox(
                            height: 46,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF059669),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                              ),
                              onPressed: _isApplying ? null : _handleApplyCode,
                              child: _isApplying
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : Text(
                                      'Apply',
                                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800),
                                    ),
                            ),
                          ),
                        ],
                      ),
                      if (_applySuccessMessage != null) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFECFDF5),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFA7F3D0)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle_rounded, color: Color(0xFF059669), size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _applySuccessMessage!,
                                  style: GoogleFonts.inter(
                                    fontSize: Responsive.scaledFontSize(context, 11.5),
                                    color: const Color(0xFF065F46),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (_applyErrorMessage != null) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF1F2),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFFECDD3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline_rounded, color: Color(0xFFE11D48), size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _applyErrorMessage!,
                                  style: GoogleFonts.inter(
                                    fontSize: Responsive.scaledFontSize(context, 11.5),
                                    color: const Color(0xFF9F1239),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // 5. Live Summary Bento Cards
                Text(
                  'Your Referral Summary',
                  style: GoogleFonts.inter(
                    fontSize: Responsive.scaledFontSize(context, 15),
                    fontWeight: FontWeight.w800,
                    color: AppDesignSystem.slate900,
                  ),
                ),
                const SizedBox(height: 10),

                statsAsync.when(
                  loading: () => Row(
                    children: [
                      Expanded(
                        child: _statCard(
                          context,
                          'Friends Joined',
                          '0',
                          Icons.people_alt_rounded,
                          const Color(0xFF1A73E8),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _statCard(
                          context,
                          'Cash Earned',
                          '₹0',
                          Icons.account_balance_wallet_rounded,
                          const Color(0xFF059669),
                        ),
                      ),
                    ],
                  ),
                  error: (_, __) => Row(
                    children: [
                      Expanded(
                        child: _statCard(
                          context,
                          'Friends Joined',
                          '0',
                          Icons.people_alt_rounded,
                          const Color(0xFF1A73E8),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _statCard(
                          context,
                          'Cash Earned',
                          '₹0',
                          Icons.account_balance_wallet_rounded,
                          const Color(0xFF059669),
                        ),
                      ),
                    ],
                  ),
                  data: (stats) {
                    final totalInvited = stats?.totalInvited ?? 0;
                    final totalEarned = stats?.totalEarned ?? 0.0;
                    final recentList = stats?.recentReferrals ?? [];

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _statCard(
                                context,
                                'Friends Joined',
                                totalInvited.toString(),
                                Icons.people_alt_rounded,
                                const Color(0xFF1A73E8),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _statCard(
                                context,
                                'Cash Earned',
                                '₹${totalEarned.toInt()}',
                                Icons.account_balance_wallet_rounded,
                                const Color(0xFF059669),
                              ),
                            ),
                          ],
                        ),

                        // Empty State or Friends List
                        if (recentList.isEmpty) ...[
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppDesignSystem.slate200),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.rocket_launch_rounded, color: Color(0xFF059669), size: 20),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Share your code on WhatsApp to earn your first ₹100 grocery cash!',
                                    style: GoogleFonts.inter(
                                      fontSize: Responsive.scaledFontSize(context, 11.5),
                                      color: AppDesignSystem.slate600,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ] else ...[
                          const SizedBox(height: 16),
                          Text(
                            'Invited Friends',
                            style: GoogleFonts.inter(
                              fontSize: Responsive.scaledFontSize(context, 13.5),
                              fontWeight: FontWeight.w800,
                              color: AppDesignSystem.slate900,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...recentList.map((r) {
                            final isDone = r['status'] == 'COMPLETED';
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: AppDesignSystem.slate200),
                                boxShadow: AppDesignSystem.shadowSm,
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 17,
                                    backgroundColor: (isDone ? const Color(0xFF059669) : const Color(0xFFF59E0B)).withValues(alpha: 0.12),
                                    child: Icon(
                                      isDone ? Icons.check_circle_rounded : Icons.hourglass_top_rounded,
                                      size: 17,
                                      color: isDone ? const Color(0xFF059669) : const Color(0xFFF59E0B),
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
                                            color: AppDesignSystem.slate900,
                                          ),
                                        ),
                                        Text(
                                          isDone ? 'First order delivered! Reward credited.' : 'Waiting for 1st order delivery',
                                          style: GoogleFonts.inter(
                                            fontSize: Responsive.scaledFontSize(context, 11),
                                            color: AppDesignSystem.slate500,
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
                                        fontWeight: FontWeight.w900,
                                        color: const Color(0xFF059669),
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
                const SizedBox(height: 20),

                // 6. How Wallet Cash Works Explainer Box
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppDesignSystem.slate200),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline_rounded, size: 18, color: AppDesignSystem.slate600),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Your referral cash is added directly to Fastkirana Wallet. At checkout, tick "Use Wallet Balance" to get instant free groceries on your orders!',
                          style: GoogleFonts.inter(
                            fontSize: Responsive.scaledFontSize(context, 11),
                            color: AppDesignSystem.slate700,
                            height: 1.45,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStepBadge(BuildContext context, String num, String label, IconData icon) {
    return Expanded(
      child: Column(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: Colors.white.withValues(alpha: 0.22),
            child: Text(
              num,
              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.white),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: Responsive.scaledFontSize(context, 10),
              fontWeight: FontWeight.w600,
              color: Colors.white,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildArrow() {
    return const Icon(Icons.chevron_right_rounded, color: Colors.white70, size: 16);
  }

  Widget _statCard(BuildContext context, String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppDesignSystem.slate200),
        boxShadow: AppDesignSystem.shadowSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 15,
            backgroundColor: color.withValues(alpha: 0.1),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: Responsive.scaledFontSize(context, 18),
              fontWeight: FontWeight.w900,
              color: AppDesignSystem.slate900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: Responsive.scaledFontSize(context, 11),
              color: AppDesignSystem.slate500,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
