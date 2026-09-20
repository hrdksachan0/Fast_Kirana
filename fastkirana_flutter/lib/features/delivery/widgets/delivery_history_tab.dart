import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/design_system.dart';
import '../../../core/services/logger_service.dart';
import 'donut_capacity_painter.dart';

/// Completed Deliveries History Tab for Rider Console
class DeliveryHistoryTab extends StatelessWidget {
  final List<Map<String, dynamic>> completed;

  const DeliveryHistoryTab({
    super.key,
    required this.completed,
  });

  static const Color slateDark = AppDesignSystem.slate900;
  static const Color slateMuted = AppDesignSystem.slate500;

  @override
  Widget build(BuildContext context) {
    const dailyTarget = 5;
    final totalCount = completed.length;

    final safeBottom = MediaQuery.of(context).padding.bottom;
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(16, 16, 16, 28 + safeBottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Daily Goal Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppDesignSystem.slate100, width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: AppDesignSystem.slate900.withValues(alpha: 0.03),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                // Gauge Ring
                CustomPaint(
                  size: const Size(64, 64),
                  painter: DonutCapacityPainter(
                    percent: math.min(1.0, totalCount / dailyTarget),
                    trackColor: AppDesignSystem.slate100,
                    progressColor: AppDesignSystem.success,
                    strokeWidth: 6,
                  ),
                  child: SizedBox(
                    width: 64,
                    height: 64,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$totalCount',
                            style: GoogleFonts.inter(
                              fontSize: Responsive.scaledFontSize(context, 18),
                              fontWeight: FontWeight.w900,
                              color: slateDark,
                            ),
                          ),
                          Text(
                            '/ $dailyTarget',
                            style: GoogleFonts.inter(
                              fontSize: Responsive.scaledFontSize(context, 9),
                              fontWeight: FontWeight.w700,
                              color: slateMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'DAILY GOAL',
                        style: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 9.5),
                          fontWeight: FontWeight.w900,
                          color: slateMuted,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(totalCount >= dailyTarget ? '🏆' : '🎯', style: TextStyle(fontSize: Responsive.scaledFontSize(context, 13))),
                          const SizedBox(width: 4),
                          Text(
                            totalCount >= dailyTarget ? 'Milestone Bonus Achieved!' : '$totalCount of $dailyTarget Completed',
                            style: GoogleFonts.inter(
                              fontSize: Responsive.scaledFontSize(context, 12.5),
                              fontWeight: FontWeight.w900,
                              color: totalCount >= dailyTarget ? AppDesignSystem.emerald600 : slateDark,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        totalCount >= dailyTarget ? 'Great hustle today! 🎉' : 'Complete ${dailyTarget - totalCount} more for bonus',
                        style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 11), color: slateMuted, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Section Title
          Row(
            children: [
              Text(
                "TODAY'S COMPLETED DELIVERIES",
                style: GoogleFonts.inter(
                  fontSize: Responsive.scaledFontSize(context, 11.5),
                  fontWeight: FontWeight.w900,
                  color: slateDark,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppDesignSystem.green100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$totalCount',
                  style: GoogleFonts.inter(
                    fontSize: Responsive.scaledFontSize(context, 10),
                    fontWeight: FontWeight.w900,
                    color: AppDesignSystem.green700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          if (completed.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppDesignSystem.slate100),
              ),
              child: Center(
                child: Text(
                  'No completed deliveries recorded yet.',
                  style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 12), color: slateMuted, fontWeight: FontWeight.w600),
                ),
              ),
            )
          else
            ...List.generate(completed.length, (idx) {
              final item = completed[idx];
              final orderId = item['id']?.toString() ?? '';
              final orderNum = item['readableId'] ?? orderId.substring(0, math.min(6, orderId.length));
              final totalAmt = (item['total'] as num?)?.toInt() ?? 0;
              final rawPm = (item['paymentMethod'] ?? '').toString().toUpperCase().trim();
              final rawPs = (item['paymentStatus'] ?? '').toString().toUpperCase().trim();
              final isCod = rawPm == 'COD' || rawPm.isEmpty;
              final isPaid = rawPs == 'PAID';
              final userObj = item['user'] is Map ? item['user'] : null;
              final userName = userObj?['name'] ?? item['userName'] ?? 'Customer';
              final addrObj = item['address'] is Map ? item['address'] : null;
              String addr = '';
              if (addrObj != null) {
                if (addrObj['formattedAddress'] != null && addrObj['formattedAddress'].toString().trim().isNotEmpty) {
                  addr = addrObj['formattedAddress'].toString().trim();
                } else {
                  final parts = [
                    addrObj['houseNo'],
                    addrObj['street'],
                    addrObj['area'],
                    addrObj['landmark'],
                    addrObj['city'],
                    addrObj['pincode'],
                  ].where((p) => p != null && p.toString().trim().isNotEmpty && p.toString() != 'null')
                   .map((p) => p.toString().trim())
                   .toList();
                  addr = parts.isNotEmpty ? parts.join(', ') : '';
                }
              }
              if (addr.isEmpty) addr = 'Ghatampur, Kanpur Nagar';
              final isLast = idx == completed.length - 1;

              String timeStr = 'Today';
              if (item['deliveredAt'] != null || item['createdAt'] != null) {
                try {
                  final dt = DateTime.parse(item['deliveredAt'] ?? item['createdAt']).toLocal();
                  timeStr = DateFormat('h:mm a').format(dt);
                } catch (e, _) { LoggerService.error('DeliveryDashboard: silent catch', e); }
              }

              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Left Timeline line + dot
                    SizedBox(
                      width: 24,
                      child: Column(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            margin: const EdgeInsets.only(top: 14),
                            decoration: const BoxDecoration(
                              color: AppDesignSystem.success,
                              shape: BoxShape.circle,
                            ),
                          ),
                          if (!isLast)
                            Expanded(
                              child: Container(
                                width: 2,
                                color: AppDesignSystem.emerald200,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Card
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppDesignSystem.slate100, width: 1.2),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      '#$orderNum',
                                      style: GoogleFonts.inter(
                                        fontSize: Responsive.scaledFontSize(context, 12.5),
                                        fontWeight: FontWeight.w900,
                                        color: slateDark,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Row(
                                      children: [
                                        const Icon(Icons.access_time_rounded, size: 11, color: slateMuted),
                                        const SizedBox(width: 3),
                                        Text(
                                          timeStr,
                                          style: GoogleFonts.inter(
                                            fontSize: Responsive.scaledFontSize(context, 10.5),
                                            fontWeight: FontWeight.w600,
                                            color: slateMuted,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    Text(
                                      '₹$totalAmt',
                                      style: GoogleFonts.inter(
                                        fontSize: Responsive.scaledFontSize(context, 13),
                                        fontWeight: FontWeight.w900,
                                        color: slateDark,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                      decoration: BoxDecoration(
                                        color: isPaid ? AppDesignSystem.green100 : (isCod ? AppDesignSystem.statusPending : AppDesignSystem.statusCancelled),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        isPaid
                                            ? (isCod ? '💵 COD RECEIVED' : (rawPm == 'UPI' ? '⚡ UPI RECEIVED' : '💳 ONLINE RECEIVED'))
                                            : (isCod ? '💵 COD' : '⚠️ UNPAID (${rawPm.isNotEmpty ? rawPm : 'ONLINE'})'),
                                        style: GoogleFonts.inter(
                                          fontSize: Responsive.scaledFontSize(context, 8.5),
                                          fontWeight: FontWeight.w900,
                                          color: isPaid ? AppDesignSystem.green700 : (isCod ? AppDesignSystem.amber700 : AppDesignSystem.red600),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        userName,
                                        style: GoogleFonts.inter(
                                          fontSize: Responsive.scaledFontSize(context, 12),
                                          fontWeight: FontWeight.w800,
                                          color: slateDark,
                                        ),
                                      ),
                                      Text(
                                        addr,
                                        style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 10.5), color: slateMuted),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppDesignSystem.green100,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'Delivered ✅',
                                    style: GoogleFonts.inter(
                                      fontSize: Responsive.scaledFontSize(context, 9.5),
                                      fontWeight: FontWeight.w800,
                                      color: AppDesignSystem.green700,
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
              );
            }),
        ],
      ),
    );
  }
}
