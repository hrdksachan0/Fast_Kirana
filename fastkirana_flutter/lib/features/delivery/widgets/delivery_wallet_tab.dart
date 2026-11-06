import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/design_system.dart';
import 'donut_capacity_painter.dart';

/// Cash Wallet & Duty Status Tab for Rider Dashboard
/// Displays:
/// 1. Today's Total Summary (Total Orders, Total Value)
/// 2. Online Payments (Cashfree / UPI) vs Cash Received (COD)
/// 3. Cash in Hand & Darkstore Deposit Capacity
/// 4. Today's Delivered Orders Breakdown List
/// 5. On Duty / Off Duty Interactive Toggle
class DeliveryWalletTab extends StatelessWidget {
  final Map<String, dynamic>? walletInfo;
  final bool isOnline;
  final ValueChanged<bool> onToggleOnline;

  const DeliveryWalletTab({
    super.key,
    required this.walletInfo,
    required this.isOnline,
    required this.onToggleOnline,
  });

  static const Color slateDark = AppDesignSystem.slate900;
  static const Color slateMuted = AppDesignSystem.slate500;

  String _formatTime(dynamic dateStr) {
    if (dateStr == null) return '';
    final dt = DateTime.tryParse(dateStr.toString())?.toLocal();
    if (dt == null) return '';
    final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final m = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $period';
  }

  @override
  Widget build(BuildContext context) {
    final wallet = walletInfo?['wallet'] is Map ? (walletInfo!['wallet'] as Map) : {};
    final summary = walletInfo?['summary'] is Map ? (walletInfo!['summary'] as Map) : {};

    final cashInHand = (wallet['cashInHand'] as num?)?.toDouble() ?? 0.0;
    final cashLimit = (wallet['cashLimit'] as num?)?.toDouble() ?? 10000.0;
    final capacityPercent = ((cashInHand / math.max(1.0, cashLimit)) * 100).clamp(0, 100).toInt();

    final totalOrdersCount = (summary['totalCount'] ?? wallet['totalOrdersCount'] as num?)?.toInt() ?? 0;
    final totalOrdersAmount = (summary['totalAmount'] ?? wallet['totalOrdersAmount'] as num?)?.toDouble() ?? 0.0;
    final onlineCount = (summary['onlineCount'] ?? wallet['onlineCount'] as num?)?.toInt() ?? 0;
    final onlineAmount = (summary['onlineAmount'] ?? wallet['onlineAmount'] as num?)?.toDouble() ?? 0.0;
    final cashCount = (summary['cashCount'] ?? wallet['cashCount'] as num?)?.toInt() ?? 0;
    final cashAmount = (summary['cashAmount'] ?? wallet['cashAmount'] as num?)?.toDouble() ?? cashInHand;

    final todayOrders = (walletInfo?['todayOrders'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];

    final safeBottom = MediaQuery.of(context).padding.bottom;
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(16, 16, 16, 28 + safeBottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── 1. TODAY'S TOTAL SUMMARY CARD (आज का पूरा हिसाब) ───
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.18),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.analytics_rounded, color: Color(0xFF38BDF8), size: 16),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'TODAY\'S SUMMARY (आज का हिसाब)',
                          style: GoogleFonts.inter(
                            fontSize: Responsive.scaledFontSize(context, 11),
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF94A3B8),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00A344).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF00A344).withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        'LIVE',
                        style: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 9.5),
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF4ADE80),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Gross Summary Banner: Total Orders + Total Revenue
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Total Orders Delivered',
                            style: GoogleFonts.inter(
                              fontSize: Responsive.scaledFontSize(context, 11.5),
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF94A3B8),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Text(
                                '$totalOrdersCount',
                                style: GoogleFonts.inter(
                                  fontSize: Responsive.scaledFontSize(context, 26),
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'orders',
                                style: GoogleFonts.inter(
                                  fontSize: Responsive.scaledFontSize(context, 12),
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 42,
                      color: Colors.white.withValues(alpha: 0.12),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Total Order Value',
                            style: GoogleFonts.inter(
                              fontSize: Responsive.scaledFontSize(context, 11.5),
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF94A3B8),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '₹${totalOrdersAmount.toInt()}',
                            style: GoogleFonts.inter(
                              fontSize: Responsive.scaledFontSize(context, 26),
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF38BDF8),
                              letterSpacing: -0.5,
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
          const SizedBox(height: 14),

          // ─── 2. 2-COLUMN SPLIT: ONLINE (Cashfree/UPI) vs CASH RECEIVED ───
          Row(
            children: [
              // Online / Cashfree Box
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFBFDBFE), width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF2563EB).withValues(alpha: 0.05),
                        blurRadius: 12,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.payment_rounded, color: Color(0xFF2563EB), size: 16),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDBEAFE),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '$onlineCount Orders',
                              style: GoogleFonts.inter(
                                fontSize: Responsive.scaledFontSize(context, 9.5),
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF1D4ED8),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '₹${onlineAmount.toInt()}',
                        style: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 20),
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF1E3A8A),
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 2),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Online (Cashfree / UPI)',
                          style: GoogleFonts.inter(
                            fontSize: Responsive.scaledFontSize(context, 10.5),
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF1E40AF),
                          ),
                          maxLines: 1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.check_circle_rounded, size: 11, color: Color(0xFF2563EB)),
                          const SizedBox(width: 4),
                          Expanded(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Direct in Store Bank',
                                style: GoogleFonts.inter(
                                  fontSize: Responsive.scaledFontSize(context, 9.5),
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF64748B),
                                ),
                                maxLines: 1,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Cash Received (COD) Box
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFFDE68A), width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFD97706).withValues(alpha: 0.05),
                        blurRadius: 12,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFFBEB),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.payments_rounded, color: Color(0xFFD97706), size: 16),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '$cashCount Orders',
                              style: GoogleFonts.inter(
                                fontSize: Responsive.scaledFontSize(context, 9.5),
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFFB45309),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '₹${cashAmount.toInt()}',
                        style: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 20),
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF78350F),
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 2),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Cash Received (COD)',
                          style: GoogleFonts.inter(
                            fontSize: Responsive.scaledFontSize(context, 10.5),
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF92400E),
                          ),
                          maxLines: 1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.account_balance_wallet_rounded, size: 11, color: Color(0xFFD97706)),
                          const SizedBox(width: 4),
                          Expanded(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Cash in Hand (जमा करें)',
                                style: GoogleFonts.inter(
                                  fontSize: Responsive.scaledFontSize(context, 9.5),
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFFB45309),
                                ),
                                maxLines: 1,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ─── 3. CASH IN HAND & CAPACITY GAUGE (DARKSTORE DEPOSIT) ───
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppDesignSystem.slate100, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: AppDesignSystem.slate900.withValues(alpha: 0.04),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                // Pill Header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppDesignSystem.statusPending,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppDesignSystem.yellow200),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.account_balance_wallet_rounded, size: 14, color: AppDesignSystem.amber700),
                      const SizedBox(width: 6),
                      Text(
                        'CASH IN HAND (जेब में नकद)',
                        style: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 11),
                          fontWeight: FontWeight.w900,
                          color: AppDesignSystem.amber700,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Amount
                Text(
                  '₹${cashInHand.toInt()}',
                  style: GoogleFonts.inter(
                    fontSize: Responsive.scaledFontSize(context, 36),
                    fontWeight: FontWeight.w900,
                    color: slateDark,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 16),

                // Circular Donut Progress Arc
                CustomPaint(
                  size: const Size(120, 120),
                  painter: DonutCapacityPainter(
                    percent: capacityPercent / 100.0,
                    trackColor: AppDesignSystem.slate100,
                    progressColor: capacityPercent >= 75 ? AppDesignSystem.amber500 : AppDesignSystem.success,
                  ),
                  child: SizedBox(
                    width: 120,
                    height: 120,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$capacityPercent%',
                            style: GoogleFonts.inter(
                              fontSize: Responsive.scaledFontSize(context, 22),
                              fontWeight: FontWeight.w900,
                              color: slateDark,
                              letterSpacing: -0.5,
                            ),
                          ),
                          Text(
                            'CAPACITY',
                            style: GoogleFonts.inter(
                              fontSize: Responsive.scaledFontSize(context, 9),
                              fontWeight: FontWeight.w800,
                              color: slateMuted,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // Status info strip
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  decoration: BoxDecoration(
                    color: capacityPercent >= 75 ? const Color(0xFFFFFBEB) : AppDesignSystem.green50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: capacityPercent >= 75 ? const Color(0xFFFDE68A) : AppDesignSystem.emerald200,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        capacityPercent >= 75 ? Icons.warning_amber_rounded : Icons.check_circle_outline_rounded,
                        size: 18,
                        color: capacityPercent >= 75 ? AppDesignSystem.amber600 : AppDesignSystem.emerald600,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          capacityPercent >= 75
                              ? 'Cash limit warning: Please deposit cash at the darkstore hub soon.'
                              : 'Shift end par ₹${cashInHand.toInt()} darkstore hub par deposit karein.',
                          style: GoogleFonts.inter(
                            fontSize: Responsive.scaledFontSize(context, 11),
                            fontWeight: FontWeight.w700,
                            color: capacityPercent >= 75 ? const Color(0xFF92400E) : AppDesignSystem.statusDeliveredText,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ─── 4. TODAY'S DELIVERED ORDERS AUDIT LIST ───
          if (todayOrders.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppDesignSystem.slate100, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: AppDesignSystem.slate900.withValues(alpha: 0.04),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.receipt_long_rounded, size: 16, color: Color(0xFF0F172A)),
                          const SizedBox(width: 6),
                          Text(
                            'TODAY\'S ORDERS BREAKDOWN',
                            style: GoogleFonts.inter(
                              fontSize: Responsive.scaledFontSize(context, 11),
                              fontWeight: FontWeight.w900,
                              color: slateDark,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${todayOrders.length} Completed',
                          style: GoogleFonts.inter(
                            fontSize: Responsive.scaledFontSize(context, 9.5),
                            fontWeight: FontWeight.w800,
                            color: slateMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: todayOrders.length,
                    separatorBuilder: (_, __) => Divider(color: const Color(0xFFF1F5F9), height: 16),
                    itemBuilder: (context, index) {
                      final ord = todayOrders[index];
                      final rawId = ord['readableId'] ?? ord['id'] ?? '';
                      final cleanId = rawId.toString().replaceAll('#', '');
                      final formattedId = cleanId.startsWith('FK-') ? '#$cleanId' : '#FK-$cleanId';
                      final total = (ord['total'] as num?)?.toDouble() ?? 0.0;
                      final pm = (ord['paymentMethod'] ?? '').toString().toUpperCase().trim();
                      final isRiderCash = ord['isRiderCash'] == true;
                      final isOnline = (pm == 'UPI' || pm == 'ONLINE' || pm == 'CASHFREE' || pm == 'RAZORPAY' || pm == 'CARD' || pm == 'WALLET') && !isRiderCash;
                      final timeStr = _formatTime(ord['deliveredAt'] ?? ord['updatedAt'] ?? ord['createdAt']);

                      return Row(
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: isOnline ? const Color(0xFFEFF6FF) : const Color(0xFFFFFBEB),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isOnline ? const Color(0xFFBFDBFE) : const Color(0xFFFDE68A),
                              ),
                            ),
                            child: Center(
                              child: Icon(
                                isOnline ? Icons.payment_rounded : Icons.payments_rounded,
                                size: 16,
                                color: isOnline ? const Color(0xFF2563EB) : const Color(0xFFD97706),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      formattedId,
                                      style: GoogleFonts.inter(
                                        fontSize: Responsive.scaledFontSize(context, 12.5),
                                        fontWeight: FontWeight.w800,
                                        color: slateDark,
                                      ),
                                    ),
                                    if (timeStr.isNotEmpty) ...[
                                      const SizedBox(width: 6),
                                      Text(
                                        '• $timeStr',
                                        style: GoogleFonts.inter(
                                          fontSize: Responsive.scaledFontSize(context, 10.5),
                                          color: slateMuted,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: isOnline ? const Color(0xFFDBEAFE) : const Color(0xFFFEF3C7),
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  child: Text(
                                    isOnline ? 'Online (Cashfree / UPI)' : 'Cash Received (COD)',
                                    style: GoogleFonts.inter(
                                      fontSize: Responsive.scaledFontSize(context, 9),
                                      fontWeight: FontWeight.w800,
                                      color: isOnline ? const Color(0xFF1D4ED8) : const Color(0xFFB45309),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '₹${total.toInt()}',
                            style: GoogleFonts.inter(
                              fontSize: Responsive.scaledFontSize(context, 14),
                              fontWeight: FontWeight.w900,
                              color: isOnline ? const Color(0xFF1E40AF) : const Color(0xFFB45309),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // ─── 5. ON DUTY / OFF DUTY INTERACTIVE TOGGLE CARD ───
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isOnline ? AppDesignSystem.emerald200 : AppDesignSystem.rose200,
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: (isOnline ? AppDesignSystem.success : AppDesignSystem.rose500).withValues(alpha: 0.06),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: isOnline ? AppDesignSystem.green100 : AppDesignSystem.statusCancelled,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isOnline ? Icons.two_wheeler_rounded : Icons.power_settings_new_rounded,
                            color: isOnline ? AppDesignSystem.green700 : AppDesignSystem.red600,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isOnline ? 'ON DUTY (ड्यूटी चालू)' : 'OFF DUTY (ड्यूटी बंद)',
                              style: GoogleFonts.inter(
                                fontSize: Responsive.scaledFontSize(context, 13.5),
                                fontWeight: FontWeight.w900,
                                color: isOnline ? AppDesignSystem.green700 : AppDesignSystem.red600,
                              ),
                            ),
                            Text(
                              isOnline ? 'Receiving live delivery orders' : 'Orders redirected to other riders',
                              style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 11), color: slateMuted, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Transform.scale(
                      scale: 0.9,
                      child: Switch(
                        value: isOnline,
                        activeThumbColor: AppDesignSystem.success,
                        activeTrackColor: AppDesignSystem.green200,
                        inactiveTrackColor: AppDesignSystem.rose200,
                        onChanged: (val) {
                          HapticFeedback.mediumImpact();
                          onToggleOnline(val);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: isOnline ? AppDesignSystem.green50 : AppDesignSystem.rose50,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isOnline ? AppDesignSystem.green200 : AppDesignSystem.rose200,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        isOnline ? Icons.info_outline_rounded : Icons.warning_amber_rounded,
                        size: 16,
                        color: isOnline ? AppDesignSystem.green700 : AppDesignSystem.red600,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          isOnline
                              ? 'Aap online hain. Store se new orders aate hi aapko pickup notification milegi.'
                              : 'Off duty hone par new orders doosre active delivery partners ke paas transfer ho jayenge.',
                          style: GoogleFonts.inter(
                            fontSize: Responsive.scaledFontSize(context, 11),
                            fontWeight: FontWeight.w600,
                            color: isOnline ? AppDesignSystem.green800 : AppDesignSystem.statusCancelledText,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
