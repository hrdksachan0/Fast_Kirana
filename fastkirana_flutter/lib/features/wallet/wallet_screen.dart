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
import 'package:intl/intl.dart';
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
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Text(
              'Verifying payment & updating wallet...',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: const Color(0xFF0F172A),
      ),
    );

    final success = await ref.read(walletNotifierProvider.notifier).syncTopupStatus(cfOrderId);
    if (!mounted) return;
    ref.invalidate(walletTransactionsProvider);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Text(
                '🎉 Wallet topped up successfully!',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          backgroundColor: AppDesignSystem.emerald600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
        content: Row(
          children: [
            const Icon(Icons.info_outline_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                msg,
                style: GoogleFonts.inter(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: AppDesignSystem.slate800,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showAddMoneySheet(BuildContext context, {int initialAmount = 500}) {
    _amountController.text = initialAmount.toString();
    bool isSubmitting = false;
    bool hasAmountError = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final currentVal = int.tryParse(_amountController.text.trim()) ?? 0;

            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
                left: 20,
                right: 20,
                top: 14,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x33000000),
                    blurRadius: 24,
                    offset: Offset(0, -6),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle Bar
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),

                  // Header Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppDesignSystem.primaryBg,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.account_balance_wallet_rounded,
                              color: AppDesignSystem.primary,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Top-up Wallet',
                                style: GoogleFonts.inter(
                                  fontSize: Responsive.scaledFontSize(ctx, 18),
                                  fontWeight: FontWeight.w800,
                                  color: AppDesignSystem.textPrimary,
                                ),
                              ),
                              Text(
                                'Instant 1-tap grocery checkout',
                                style: GoogleFonts.inter(
                                  fontSize: Responsive.scaledFontSize(ctx, 12),
                                  color: AppDesignSystem.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      IconButton(
                        icon: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close_rounded, size: 18),
                        ),
                        onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Amount Display / Input Card (Style 1 Luxury Floating-Label Card)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: hasAmountError
                            ? const Color(0xFFEF4444)
                            : const Color(0xFFE20A22),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: hasAmountError
                              ? const Color(0xFFEF4444).withValues(alpha: 0.12)
                              : const Color(0xFFE20A22).withValues(alpha: 0.08),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Micro Header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.account_balance_wallet_outlined,
                                  size: 15,
                                  color: Color(0xFFE20A22),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'ENTER TOP-UP AMOUNT',
                                  style: GoogleFonts.inter(
                                    fontSize: Responsive.scaledFontSize(ctx, 10),
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5,
                                    color: hasAmountError ? const Color(0xFFEF4444) : const Color(0xFFE20A22),
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFECFDF5),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Text(
                                'Instant • 0% Fee',
                                style: GoogleFonts.inter(
                                  fontSize: Responsive.scaledFontSize(ctx, 9.5),
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF059669),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        // Input Row with Currency Badge
                        Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF1F2),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFFECDD3), width: 1.2),
                              ),
                              child: Center(
                                child: Text(
                                  '₹',
                                  style: GoogleFonts.inter(
                                    fontSize: Responsive.scaledFontSize(ctx, 22),
                                    fontWeight: FontWeight.w900,
                                    color: const Color(0xFFE20A22),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: _amountController,
                                keyboardType: TextInputType.number,
                                enabled: !isSubmitting,
                                autofocus: true,
                                onChanged: (_) {
                                  setSheetState(() {
                                    if (hasAmountError) hasAmountError = false;
                                  });
                                },
                                style: GoogleFonts.inter(
                                  fontSize: Responsive.scaledFontSize(ctx, 28),
                                  fontWeight: FontWeight.w900,
                                  color: const Color(0xFF0F172A),
                                  letterSpacing: -0.5,
                                ),
                                decoration: const InputDecoration(
                                  hintText: '0',
                                  hintStyle: TextStyle(color: Color(0xFF94A3B8)),
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  disabledBorder: InputBorder.none,
                                  isDense: true,
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),
                            ),
                            if (_amountController.text.isNotEmpty && !isSubmitting)
                              GestureDetector(
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  setSheetState(() {
                                    _amountController.clear();
                                    if (hasAmountError) hasAmountError = false;
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFF1F5F9),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.close_rounded, color: Color(0xFF64748B), size: 16),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (hasAmountError) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.error_outline_rounded, size: 14, color: Color(0xFFEF4444)),
                        const SizedBox(width: 5),
                        Text(
                          'Minimum top-up amount is ₹10',
                          style: GoogleFonts.inter(
                            fontSize: Responsive.scaledFontSize(ctx, 11.5),
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFFEF4444),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),
                  // Quick Amount Chips
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [200, 500, 1000, 2000].map((amt) {
                      final isSelected = currentVal == amt;
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: InkWell(
                            onTap: isSubmitting
                                ? null
                                : () {
                                    HapticFeedback.lightImpact();
                                    setSheetState(() {
                                      _amountController.text = amt.toString();
                                    });
                                  },
                            borderRadius: BorderRadius.circular(12),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: isSelected ? AppDesignSystem.primary : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected ? AppDesignSystem.primary : Colors.transparent,
                                ),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: AppDesignSystem.primary.withValues(alpha: 0.3),
                                          blurRadius: 8,
                                          offset: const Offset(0, 3),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Center(
                                child: Text(
                                  '+₹$amt',
                                  style: GoogleFonts.inter(
                                    fontSize: Responsive.scaledFontSize(ctx, 13),
                                    fontWeight: FontWeight.w700,
                                    color: isSelected ? Colors.white : AppDesignSystem.slate800,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),

                  // Trust & Supported Payments Strip
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.shield_rounded, color: AppDesignSystem.emerald600, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'All payment modes: UPI (GPay/PhonePe), Cards, Netbanking & Wallets supported.',
                            style: GoogleFonts.inter(
                              fontSize: Responsive.scaledFontSize(ctx, 11),
                              color: AppDesignSystem.slate600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),

                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppDesignSystem.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 4,
                        shadowColor: AppDesignSystem.primary.withValues(alpha: 0.4),
                      ),
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              final val = double.tryParse(_amountController.text.trim()) ?? 0.0;
                              if (val < 10) {
                                HapticFeedback.heavyImpact();
                                setSheetState(() => hasAmountError = true);
                                return;
                              }

                              setSheetState(() => isSubmitting = true);
                              final res = await ref.read(walletNotifierProvider.notifier).initiateTopup(val);

                              if (!ctx.mounted) return;
                              Navigator.pop(ctx);

                              if (res == null || res['paymentSessionId'] == null) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Payment initiation failed. Please check connection and try again.',
                                        style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                                      ),
                                      backgroundColor: AppDesignSystem.slate800,
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
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.lock_outline_rounded, color: Colors.white, size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  'Proceed to Pay ₹${_amountController.text.trim().isEmpty ? '0' : _amountController.text.trim()}',
                                  style: GoogleFonts.inter(
                                    fontSize: Responsive.scaledFontSize(ctx, 15),
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),

                  const SizedBox(height: 12),
                  Center(
                    child: Text(
                      'Secured by Cashfree Payments • RBI Licensed Payment Aggregator',
                      style: GoogleFonts.inter(
                        fontSize: Responsive.scaledFontSize(ctx, 10.5),
                        color: AppDesignSystem.slate400,
                        fontWeight: FontWeight.w500,
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

  String _cleanTxDescription(String raw, String type) {
    final trimmed = raw.replaceAll('👛', '').trim();
    final lower = trimmed.toLowerCase();
    if (lower.isEmpty) {
      return type == 'CREDIT' ? 'Wallet Top-up' : 'Wallet Payment';
    }

    // Extract Order ID if present (e.g. Order #2989, #2989, Order 2989, or #FM-2989)
    final orderMatch = RegExp(r'(?:order\s*#?|#)([A-Za-z0-9\-]+)', caseSensitive: false).firstMatch(trimmed);
    final orderId = orderMatch != null ? '#${orderMatch.group(1)}' : '';

    if (lower.contains('refund')) {
      return orderId.isNotEmpty ? 'Refund • $orderId' : 'Order Refund';
    }
    if (lower.contains('wallet deduction') ||
        lower.contains('payment for order') ||
        lower.contains('paid for order')) {
      return orderId.isNotEmpty ? 'Paid for $orderId' : 'Order Payment';
    }
    if (lower.startsWith('wallet top-up') ||
        lower.startsWith('wallet topup') ||
        lower.contains('top-up of') ||
        lower.contains('topup of')) {
      return 'Wallet Top-up';
    }
    if (lower.contains('referral reward') || lower.contains('referral bonus') || lower.contains('referral')) {
      return 'Referral Cashback';
    }
    if (lower.contains('cashback')) {
      return 'Cashback Reward';
    }
    if (orderId.isNotEmpty) {
      return 'Order $orderId';
    }
    return trimmed;
  }

  String _formatDateTime(String? raw) {
    if (raw == null || raw.isEmpty) return 'Recent';
    try {
      final dt = DateTime.parse(raw).toLocal();
      final now = DateTime.now();
      if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
        return 'Today, ${DateFormat('hh:mm a').format(dt)}';
      }
      return DateFormat('dd MMM, hh:mm a').format(dt);
    } catch (_) {
      return raw.split('T').first;
    }
  }

  @override
  Widget build(BuildContext context) {
    final wallet = ref.watch(walletNotifierProvider);
    final txAsync = ref.watch(walletTransactionsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), // Ultra-clean executive slate 50
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: AppDesignSystem.slate900),
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
              'FastMinute Wallet',
              style: GoogleFonts.inter(
                fontSize: Responsive.scaledFontSize(context, 16.5),
                fontWeight: FontWeight.w800,
                color: AppDesignSystem.slate900,
                letterSpacing: -0.3,
              ),
            ),
            Text(
              'Zero-failure 1-tap grocery payments',
              style: GoogleFonts.inter(
                fontSize: Responsive.scaledFontSize(context, 10.5),
                color: AppDesignSystem.slate500,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh Balance',
            icon: Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppDesignSystem.slate200),
                boxShadow: AppDesignSystem.shadowSm,
              ),
              child: const Icon(Icons.refresh_rounded, size: 18, color: AppDesignSystem.slate700),
            ),
            onPressed: () {
              HapticFeedback.lightImpact();
              ref.read(walletNotifierProvider.notifier).fetchBalance();
              ref.invalidate(walletTransactionsProvider);
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        color: AppDesignSystem.primary,
        onRefresh: () async {
          await ref.read(walletNotifierProvider.notifier).fetchBalance();
          ref.invalidate(walletTransactionsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          children: [
            // ==========================================
            // LUXURY HERO OBSIDIAN BALANCE CARD (Zepto / Cred Grade)
            // ==========================================
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF0F172A), // Deep Slate Obsidian
                    Color(0xFF1E293B), // Midnight Blue Slate
                    Color(0xFF0F172A),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(color: Colors.white.withValues(alpha: 0.12), width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.35),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // Decorative ambient glowing orbs
                  Positioned(
                    top: -24,
                    right: -24,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppDesignSystem.emerald600.withValues(alpha: 0.18),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -30,
                    left: -20,
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppDesignSystem.primary.withValues(alpha: 0.14),
                      ),
                    ),
                  ),

                  // Main Card Content
                  Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Top Header Row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(5),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(7),
                                  ),
                                  child: const Icon(
                                    Icons.bolt_rounded,
                                    color: Color(0xFF34D399),
                                    size: 15,
                                  ),
                                ),
                                const SizedBox(width: 7),
                                Text(
                                  'FASTMINUTE CASH',
                                  style: GoogleFonts.inter(
                                    fontSize: Responsive.scaledFontSize(context, 10.5),
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.2,
                                    color: const Color(0xFF94A3B8),
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: const Color(0xFF10B981).withValues(alpha: 0.3),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 5,
                                    height: 5,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Color(0xFF34D399),
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    'Active & Protected',
                                    style: GoogleFonts.inter(
                                      fontSize: Responsive.scaledFontSize(context, 10),
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF6EE7B7),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Balance Label
                        Text(
                          'Total Usable Balance',
                          style: GoogleFonts.inter(
                            fontSize: Responsive.scaledFontSize(context, 11),
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF94A3B8),
                          ),
                        ),
                        const SizedBox(height: 3),

                        // Big Bold Balance Typography
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              '₹',
                              style: GoogleFonts.inter(
                                fontSize: Responsive.scaledFontSize(context, 22),
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF34D399),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              wallet.totalUsable.toStringAsFixed(2),
                              style: GoogleFonts.inter(
                                fontSize: Responsive.scaledFontSize(context, 32),
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: -0.8,
                              ),
                            ),
                          ],
                        ),

                        // Split Pills Breakdown
                        if (wallet.promoBalance > 0) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.card_giftcard_rounded, color: Color(0xFFFCD34D), size: 13),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'Includes ₹${wallet.promoBalance.toStringAsFixed(2)} Referral Cashback (Directly usable on orders)',
                                    style: GoogleFonts.inter(
                                      fontSize: Responsive.scaledFontSize(context, 10.5),
                                      color: const Color(0xFFFDE68A),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 16),

                        // Action Buttons Row
                        Row(
                          children: [
                            // Primary Add Money Button
                            Expanded(
                              flex: 3,
                              child: InkWell(
                                onTap: () {
                                  HapticFeedback.lightImpact();
                                  _showAddMoneySheet(context);
                                },
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 10.5),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFF10B981), Color(0xFF059669)],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF10B981).withValues(alpha: 0.4),
                                        blurRadius: 10,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.add_circle_outline_rounded, color: Colors.white, size: 16),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Add Money',
                                        style: GoogleFonts.inter(
                                          fontSize: Responsive.scaledFontSize(context, 12.5),
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),

                            // Invite & Earn Secondary Button
                            Expanded(
                              flex: 3,
                              child: InkWell(
                                onTap: () {
                                  HapticFeedback.lightImpact();
                                  Navigator.pushNamed(context, '/referral');
                                },
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 10.5),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.white.withValues(alpha: 0.22),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.celebration_rounded, color: Color(0xFFFCD34D), size: 16),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Invite & Earn',
                                        style: GoogleFonts.inter(
                                          fontSize: Responsive.scaledFontSize(context, 12.5),
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // ==========================================
            // QUICK TOP-UP PRESET STRIP
            // ==========================================
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppDesignSystem.slate200),
                boxShadow: AppDesignSystem.shadowSm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.flash_on_rounded, color: AppDesignSystem.warning, size: 15),
                      const SizedBox(width: 5),
                      Text(
                        'QUICK TOP-UP',
                        style: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 10.5),
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          color: AppDesignSystem.slate700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [200, 500, 1000, 2000].map((amt) {
                      final isPopular = amt == 500;
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: InkWell(
                            onTap: () => _showAddMoneySheet(context, initialAmount: amt),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 7.5),
                              decoration: BoxDecoration(
                                color: isPopular
                                    ? AppDesignSystem.primaryBg
                                    : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isPopular
                                      ? AppDesignSystem.primary.withValues(alpha: 0.5)
                                      : AppDesignSystem.slate200,
                                  width: isPopular ? 1.4 : 1,
                                ),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '+₹$amt',
                                    style: GoogleFonts.inter(
                                      fontSize: Responsive.scaledFontSize(context, 11.5),
                                      fontWeight: FontWeight.w800,
                                      color: isPopular ? AppDesignSystem.primary : AppDesignSystem.slate800,
                                    ),
                                  ),
                                  if (isPopular)
                                    Text(
                                      'POPULAR',
                                      style: GoogleFonts.inter(
                                        fontSize: Responsive.scaledFontSize(context, 8),
                                        fontWeight: FontWeight.w800,
                                        color: AppDesignSystem.primaryDark,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // ==========================================
            // TRUST & BENEFITS BENTO GRID (Zepto / Blinkit style)
            // ==========================================
            Row(
              children: [
                _buildBenefitBento(
                  context,
                  icon: Icons.bolt_rounded,
                  iconColor: const Color(0xFFF59E0B),
                  bgColor: const Color(0xFFFFFBEB),
                  title: '1-Tap Pay',
                  desc: 'Zero OTP & no bank drop',
                ),
                const SizedBox(width: 8),
                _buildBenefitBento(
                  context,
                  icon: Icons.autorenew_rounded,
                  iconColor: const Color(0xFF3B82F6),
                  bgColor: const Color(0xFFEFF6FF),
                  title: 'Auto Refund',
                  desc: 'Back in wallet in 2s',
                ),
                const SizedBox(width: 8),
                _buildBenefitBento(
                  context,
                  icon: Icons.verified_user_rounded,
                  iconColor: const Color(0xFF10B981),
                  bgColor: const Color(0xFFECFDF5),
                  title: 'Cashfree Safe',
                  desc: '256-bit Bank Grade',
                ),
              ],
            ),
            const SizedBox(height: 18),

            // ==========================================
            // TRANSACTION PASSBOOK HEADER
            // ==========================================
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Transaction Passbook',
                  style: GoogleFonts.inter(
                    fontSize: Responsive.scaledFontSize(context, 15),
                    fontWeight: FontWeight.w800,
                    color: AppDesignSystem.slate900,
                    letterSpacing: -0.3,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFA7F3D0)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle_rounded, color: Color(0xFF059669), size: 12),
                      const SizedBox(width: 3.5),
                      Text(
                        'Verified Only',
                        style: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 10),
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF047857),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // ==========================================
            // TRANSACTIONS LIST / PASSBOOK
            // ==========================================
            txAsync.when(
              loading: () => Container(
                padding: const EdgeInsets.all(32),
                alignment: Alignment.center,
                child: const CircularProgressIndicator(color: AppDesignSystem.primary),
              ),
              error: (err, _) => Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppDesignSystem.slate200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, color: AppDesignSystem.danger),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Failed to load passbook: $err',
                        style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 12)),
                      ),
                    ),
                  ],
                ),
              ),
              data: (txList) {
                if (txList.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppDesignSystem.slate200),
                      boxShadow: AppDesignSystem.shadowSm,
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFFF1F5F9),
                            border: Border.all(color: AppDesignSystem.slate200),
                          ),
                          child: const Icon(
                            Icons.receipt_long_rounded,
                            size: 30,
                            color: AppDesignSystem.slate400,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'No transactions yet',
                          style: GoogleFonts.inter(
                            fontSize: Responsive.scaledFontSize(context, 15),
                            color: AppDesignSystem.slate800,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Top up your wallet or invite friends to earn free grocery cash!',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: Responsive.scaledFontSize(context, 12),
                            color: AppDesignSystem.slate500,
                          ),
                        ),
                        const SizedBox(height: 18),
                        ElevatedButton.icon(
                          onPressed: () => _showAddMoneySheet(context, initialAmount: 500),
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: Text(
                            'Add ₹500 Now',
                            style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppDesignSystem.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (context, idx) {
                    final t = txList[idx];
                    final isCredit = t.isCredit;

                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8.5),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFF1F5F9)),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          // Icon container (Compact 34x34)
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: isCredit ? const Color(0xFFECFDF5) : const Color(0xFFFFF1F2),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isCredit ? const Color(0xFFA7F3D0) : const Color(0xFFFECDD3),
                                width: 0.8,
                              ),
                            ),
                            child: Icon(
                              isCredit ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                              size: 16,
                              color: isCredit ? const Color(0xFF059669) : const Color(0xFFE11D48),
                            ),
                          ),
                          const SizedBox(width: 10),

                          // Description and date
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _cleanTxDescription(t.description, t.type),
                                  style: GoogleFonts.inter(
                                    fontSize: Responsive.scaledFontSize(context, 12.5),
                                    fontWeight: FontWeight.w700,
                                    color: AppDesignSystem.slate900,
                                    height: 1.2,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  softWrap: true,
                                ),
                                const SizedBox(height: 3),
                                Wrap(
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  spacing: 5,
                                  runSpacing: 2,
                                  children: [
                                    Text(
                                      _formatDateTime(t.createdAt),
                                      style: GoogleFonts.inter(
                                        fontSize: Responsive.scaledFontSize(context, 10.5),
                                        color: AppDesignSystem.slate500,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 4.5, vertical: 1.0),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFECFDF5),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: const Color(0xFFA7F3D0), width: 0.8),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.check_circle_rounded, size: 8.5, color: Color(0xFF059669)),
                                          const SizedBox(width: 2.5),
                                          Text(
                                            'Success',
                                            style: GoogleFonts.inter(
                                              fontSize: Responsive.scaledFontSize(context, 8.5),
                                              fontWeight: FontWeight.w700,
                                              color: const Color(0xFF059669),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),

                          // Amount
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${isCredit ? '+' : '-'}₹${t.amount.toStringAsFixed(2)}',
                                style: GoogleFonts.inter(
                                  fontSize: Responsive.scaledFontSize(context, 13.5),
                                  fontWeight: FontWeight.w800,
                                  color: isCredit ? const Color(0xFF059669) : const Color(0xFFE11D48),
                                ),
                              ),
                              if (t.balanceAfter > 0) ...[
                                const SizedBox(height: 1.5),
                                Text(
                                  'Bal: ₹${t.balanceAfter.toStringAsFixed(2)}',
                                  style: GoogleFonts.inter(
                                    fontSize: Responsive.scaledFontSize(context, 9.5),
                                    color: AppDesignSystem.slate400,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ],
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

  Widget _buildBenefitBento(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required String title,
    required String desc,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppDesignSystem.slate200),
          boxShadow: AppDesignSystem.shadowSm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: iconColor, size: 14),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: Responsive.scaledFontSize(context, 11),
                fontWeight: FontWeight.w800,
                color: AppDesignSystem.slate900,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              desc,
              style: GoogleFonts.inter(
                fontSize: Responsive.scaledFontSize(context, 9.5),
                color: AppDesignSystem.slate500,
                height: 1.15,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
