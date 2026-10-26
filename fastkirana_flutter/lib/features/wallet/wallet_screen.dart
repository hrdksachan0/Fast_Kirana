import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_cashfree_pg_sdk/api/cferrorresponse/cferrorresponse.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfpayment/cfwebcheckoutpayment.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfpaymentgateway/cfpaymentgatewayservice.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfsession/cfsession.dart';
import 'package:flutter_cashfree_pg_sdk/api/cftheme/cftheme.dart';
import 'package:flutter_cashfree_pg_sdk/utils/cfenums.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/config/app_config.dart';
import '../../core/theme/design_system.dart';
import '../../providers/wallet_provider.dart';

class WalletScreen extends ConsumerStatefulWidget {
  const WalletScreen({super.key});

  @override
  ConsumerState<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends ConsumerState<WalletScreen> {
  final TextEditingController _amountController = TextEditingController(text: '500');
  final CFPaymentGatewayService _cfService = CFPaymentGatewayService();

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _cfService.setCallback(_onPaymentSuccess, _onPaymentError);
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _onPaymentSuccess(String cfOrderId) async {
    HapticFeedback.heavyImpact();
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
            SizedBox(width: 12),
            Text('Verifying payment & updating wallet...'),
          ],
        ),
        duration: Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
      ),
    );

    final success = await ref.read(walletNotifierProvider.notifier).syncTopupStatus(cfOrderId);
    if (!mounted) return;
    ref.invalidate(walletTransactionsProvider);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🎉 Wallet topped up successfully!'),
          backgroundColor: AppDesignSystem.emerald600,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      await Future.delayed(const Duration(seconds: 2));
      await ref.read(walletNotifierProvider.notifier).fetchBalance();
      if (mounted) ref.invalidate(walletTransactionsProvider);
    }
  }

  void _onPaymentError(CFErrorResponse error, String cfOrderId) {
    if (!mounted) return;
    final msg = error.getMessage() ?? 'Payment was cancelled or failed';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppDesignSystem.slate800,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showAddMoneySheet(BuildContext context) {
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
                left: 20,
                right: 20,
                top: 24,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Add Money to Wallet',
                        style: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(ctx, 18),
                          fontWeight: FontWeight.w800,
                          color: AppDesignSystem.textPrimary,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Instant 1-tap checkout for your daily grocery orders with zero payment failures.',
                    style: GoogleFonts.inter(
                      fontSize: Responsive.scaledFontSize(ctx, 13),
                      color: AppDesignSystem.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    enabled: !isSubmitting,
                    style: GoogleFonts.inter(
                      fontSize: Responsive.scaledFontSize(ctx, 28),
                      fontWeight: FontWeight.w800,
                      color: AppDesignSystem.primary,
                    ),
                    decoration: InputDecoration(
                      prefixText: '₹ ',
                      prefixStyle: GoogleFonts.inter(
                        fontSize: Responsive.scaledFontSize(ctx, 28),
                        fontWeight: FontWeight.w800,
                        color: AppDesignSystem.primary,
                      ),
                      hintText: '0',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: AppDesignSystem.borderLight),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: AppDesignSystem.primary, width: 2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [200, 500, 1000, 2000].map((amt) {
                      return GestureDetector(
                        onTap: isSubmitting
                            ? null
                            : () {
                                setSheetState(() {
                                  _amountController.text = amt.toString();
                                });
                              },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppDesignSystem.surface,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppDesignSystem.borderLight),
                          ),
                          child: Text(
                            '+₹$amt',
                            style: GoogleFonts.inter(
                              fontSize: Responsive.scaledFontSize(ctx, 13),
                              fontWeight: FontWeight.w700,
                              color: AppDesignSystem.textPrimary,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppDesignSystem.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              final val = double.tryParse(_amountController.text.trim()) ?? 0.0;
                              if (val < 10) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Minimum topup amount is ₹10')),
                                );
                                return;
                              }

                              setSheetState(() => isSubmitting = true);
                              final res = await ref.read(walletNotifierProvider.notifier).initiateTopup(val);

                              if (!ctx.mounted) return;
                              Navigator.pop(ctx);

                              if (res == null || res['paymentSessionId'] == null) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Payment initiation failed. Please try again.'),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                                return;
                              }

                              final String paymentSessionId = res['paymentSessionId'].toString();
                              final String cfOrderId = res['cfOrderId']?.toString() ??
                                  'WTOPUP_${DateTime.now().millisecondsSinceEpoch}';

                              const env = AppConfig.cashfreeEnv == 'SANDBOX'
                                  ? CFEnvironment.SANDBOX
                                  : CFEnvironment.PRODUCTION;
                              final session = CFSessionBuilder()
                                  .setEnvironment(env)
                                  .setOrderId(cfOrderId)
                                  .setPaymentSessionId(paymentSessionId)
                                  .build();

                              final theme = CFThemeBuilder()
                                  .setNavigationBarBackgroundColorColor("#E20A22")
                                  .setNavigationBarTextColor("#FFFFFF")
                                  .setButtonBackgroundColor("#E20A22")
                                  .setButtonTextColor("#FFFFFF")
                                  .setPrimaryTextColor("#0F172A")
                                  .setBackgroundColor("#FFFFFF")
                                  .setPrimaryFont("Inter")
                                  .build();

                              // Launch full Cashfree Unified Checkout (UPI, Cards, Netbanking & Wallets)
                              try {
                                final cfWeb = CFWebCheckoutPaymentBuilder()
                                    .setSession(session)
                                    .setTheme(theme)
                                    .build();
                                _cfService.doPayment(cfWeb);
                              } catch (e) {
                                debugPrint('Cashfree Web Checkout error: $e');
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Payment launch error: $e')),
                                  );
                                }
                              }
                            },
                      child: isSubmitting
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.2),
                            )
                          : Text(
                              'Proceed to Pay via UPI / Card',
                              style: GoogleFonts.inter(
                                fontSize: Responsive.scaledFontSize(ctx, 15),
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final wallet = ref.watch(walletNotifierProvider);
    final txAsync = ref.watch(walletTransactionsProvider);

    return Scaffold(
      backgroundColor: AppDesignSystem.background,
      appBar: AppBar(
        backgroundColor: AppDesignSystem.background,
        elevation: 0,
        title: Text(
          'Fastkirana Wallet',
          style: GoogleFonts.inter(
            fontSize: Responsive.scaledFontSize(context, 18),
            fontWeight: FontWeight.w800,
            color: AppDesignSystem.textPrimary,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(walletNotifierProvider.notifier).fetchBalance();
          ref.invalidate(walletTransactionsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Balance Card
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
                    'Available Balance',
                    style: GoogleFonts.inter(
                      fontSize: Responsive.scaledFontSize(context, 13),
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '₹${wallet.totalUsable.toStringAsFixed(2)}',
                    style: GoogleFonts.inter(
                      fontSize: Responsive.scaledFontSize(context, 38),
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  if (wallet.promoBalance > 0) ...[
                    const SizedBox(height: 4),
                    Text(
                      '(Includes ₹${wallet.promoBalance.toStringAsFixed(2)} Referral/Promo Cash)',
                      style: GoogleFonts.inter(
                        fontSize: Responsive.scaledFontSize(context, 11),
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _action(
                        context,
                        'Add Money',
                        Icons.add_circle_rounded,
                        () => _showAddMoneySheet(context),
                      ),
                      const SizedBox(width: 16),
                      _action(
                        context,
                        'Invite & Earn',
                        Icons.card_giftcard_rounded,
                        () => Navigator.pushNamed(context, '/referral'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Benefit Pill
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppDesignSystem.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppDesignSystem.primary.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.bolt_rounded, color: AppDesignSystem.primary, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '1-Tap Instant Checkout on grocery orders with zero OTP or bank server failures.',
                      style: GoogleFonts.inter(
                        fontSize: Responsive.scaledFontSize(context, 12),
                        fontWeight: FontWeight.w600,
                        color: AppDesignSystem.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Transaction History Header
            Text(
              'Transaction History',
              style: GoogleFonts.inter(
                fontSize: Responsive.scaledFontSize(context, 16),
                fontWeight: FontWeight.w800,
                color: AppDesignSystem.textPrimary,
              ),
            ),
            const SizedBox(height: 12),

            // Transactions List
            txAsync.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (err, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('Failed to load transactions: $err'),
                ),
              ),
              data: (txList) {
                if (txList.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(32),
                    alignment: Alignment.center,
                    child: Column(
                      children: [
                        Icon(Icons.receipt_long_outlined, size: 48, color: AppDesignSystem.textSecondary.withValues(alpha: 0.4)),
                        const SizedBox(height: 8),
                        Text(
                          'No transactions yet',
                          style: GoogleFonts.inter(
                            fontSize: Responsive.scaledFontSize(context, 14),
                            color: AppDesignSystem.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: txList.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, idx) {
                    final t = txList[idx];
                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppDesignSystem.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppDesignSystem.borderLight),
                        boxShadow: AppDesignSystem.shadowSm,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: (t.isCredit ? AppDesignSystem.success : AppDesignSystem.danger).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Center(
                              child: Icon(
                                t.isCredit ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                                size: 18,
                                color: t.isCredit ? AppDesignSystem.success : AppDesignSystem.danger,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  t.description,
                                  style: GoogleFonts.inter(
                                    fontSize: Responsive.scaledFontSize(context, 13),
                                    fontWeight: FontWeight.w700,
                                    color: AppDesignSystem.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  t.createdAt != null ? t.createdAt!.split('T').first : 'Recent',
                                  style: GoogleFonts.inter(
                                    fontSize: Responsive.scaledFontSize(context, 11),
                                    color: AppDesignSystem.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '${t.isCredit ? '+' : '-'}₹${t.amount.toStringAsFixed(2)}',
                            style: GoogleFonts.inter(
                              fontSize: Responsive.scaledFontSize(context, 15),
                              fontWeight: FontWeight.w800,
                              color: t.isCredit ? AppDesignSystem.success : AppDesignSystem.danger,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _action(BuildContext context, String label, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: Responsive.scaledFontSize(context, 12),
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
