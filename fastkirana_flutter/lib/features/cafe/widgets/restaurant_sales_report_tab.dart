import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bounceable/flutter_bounceable.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/design_system.dart';

class RestaurantSalesReportTab extends StatefulWidget {
  final List<dynamic> salesOrders;
  final Map<String, dynamic> salesSummary;
  final double commissionRate;
  final Color primaryRed;
  final Color brandGreen;
  final Color slateDark;
  final Color slateMuted;
  final Color slateBorder;

  const RestaurantSalesReportTab({
    super.key,
    required this.salesOrders,
    required this.salesSummary,
    required this.commissionRate,
    this.primaryRed = AppDesignSystem.primary,
    this.brandGreen = AppDesignSystem.success,
    this.slateDark = AppDesignSystem.slate900,
    this.slateMuted = AppDesignSystem.slate500,
    this.slateBorder = AppDesignSystem.slate200,
  });

  @override
  State<RestaurantSalesReportTab> createState() => _RestaurantSalesReportTabState();
}

class _RestaurantSalesReportTabState extends State<RestaurantSalesReportTab> {
  String _selectedSalesPeriod = 'TODAY';

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final yesterdayStart = todayStart.subtract(const Duration(days: 1));
    final weekStart = now.subtract(const Duration(days: 7));
    final monthStart = DateTime(now.year, now.month, 1);

    final filteredOrdersList = widget.salesOrders.where((o) {
      final status = o['status']?.toString().toUpperCase() ?? '';
      if (status == 'CANCELLED') return false;
      final dt = DateTime.tryParse(o['createdAt']?.toString() ?? '');
      if (dt == null) return true;

      switch (_selectedSalesPeriod) {
        case 'YESTERDAY':
          return dt.isAfter(yesterdayStart) && dt.isBefore(todayStart);
        case 'WEEK':
          return dt.isAfter(weekStart);
        case 'MONTH':
          return dt.isAfter(monthStart);
        case 'ALL':
          return true;
        case 'TODAY':
        default:
          return dt.isAfter(todayStart);
      }
    }).toList();

    double calculatedGrossSales = 0.0;
    for (final o in filteredOrdersList) {
      final dynamic rawItems = o['items'];
      if (rawItems is List && rawItems.isNotEmpty) {
        double orderFoodSum = 0.0;
        for (final it in rawItems) {
          final num p = (it['price'] is num) ? (it['price'] as num) : (num.tryParse(it['price']?.toString() ?? '0') ?? 0);
          final int q = (it['quantity'] is num) ? (it['quantity'] as num).toInt() : (int.tryParse(it['quantity']?.toString() ?? '1') ?? 1);
          orderFoodSum += (p * q).toDouble();
        }
        calculatedGrossSales += orderFoodSum;
      } else {
        final num sub = (o['subtotal'] is num) ? (o['subtotal'] as num) : (num.tryParse(o['subtotal']?.toString() ?? '0') ?? 0);
        if (sub > 0) {
          calculatedGrossSales += sub.toDouble();
        } else {
          final num tot = (o['total'] is num) ? (o['total'] as num) : (num.tryParse(o['total']?.toString() ?? '0') ?? 0);
          final num del = (o['deliveryFee'] is num) ? (o['deliveryFee'] as num) : (num.tryParse(o['deliveryFee']?.toString() ?? '0') ?? 0);
          final num misc = (o['miscFee'] is num) ? (o['miscFee'] as num) : (num.tryParse(o['miscFee']?.toString() ?? '0') ?? 0);
          calculatedGrossSales += math.max(0.0, (tot - del - misc).toDouble());
        }
      }
    }

    final num apiTotalSales = (widget.salesSummary['totalSales'] is num)
        ? (widget.salesSummary['totalSales'] as num)
        : (num.tryParse(widget.salesSummary['totalSales']?.toString() ?? '0') ?? 0);

    final double totalSales = (_selectedSalesPeriod == 'TODAY' && calculatedGrossSales == 0 && apiTotalSales > 0)
        ? apiTotalSales.toDouble()
        : calculatedGrossSales;

    final int ordersCount = filteredOrdersList.length;
    final double commPercent = widget.commissionRate;

    final double commissionDeduction = totalSales * (commPercent / 100.0);
    final double netProfit = math.max(0.0, totalSales - commissionDeduction);

    String periodTitle = "Today's Net Settlement";
    if (_selectedSalesPeriod == 'YESTERDAY') {
      periodTitle = "Yesterday's Net Settlement";
    } else if (_selectedSalesPeriod == 'WEEK') {
      periodTitle = "Last 7 Days Net Settlement";
    } else if (_selectedSalesPeriod == 'MONTH') {
      periodTitle = "This Month's Net Settlement";
    } else if (_selectedSalesPeriod == 'ALL') {
      periodTitle = "All Time Net Settlement";
    }

    final periods = [
      {'id': 'TODAY', 'label': 'Today'},
      {'id': 'YESTERDAY', 'label': 'Yesterday'},
      {'id': 'WEEK', 'label': 'Last 7 Days'},
      {'id': 'MONTH', 'label': 'This Month'},
      {'id': 'ALL', 'label': 'All Time'},
    ];

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Date-wise Filter Bar
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: periods.map((p) {
                final isSel = _selectedSalesPeriod == p['id'];
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Bounceable(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      setState(() => _selectedSalesPeriod = p['id']!);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSel ? widget.primaryRed : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: isSel ? widget.primaryRed : widget.slateBorder),
                        boxShadow: isSel
                            ? [
                                BoxShadow(
                                  color: widget.primaryRed.withValues(alpha: 0.25),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Text(
                        p['label']!,
                        style: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 12),
                          fontWeight: FontWeight.w800,
                          color: isSel ? Colors.white : widget.slateDark,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),

          // 2. Net Settlement Highlight Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [widget.primaryRed, AppDesignSystem.red800],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(color: widget.primaryRed.withValues(alpha: 0.35), blurRadius: 14, offset: const Offset(0, 5)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  periodTitle,
                  style: GoogleFonts.inter(
                    fontSize: Responsive.scaledFontSize(context, 12.5),
                    color: Colors.white.withValues(alpha: 0.9),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '₹${netProfit.toStringAsFixed(2)}',
                  style: GoogleFonts.inter(
                    fontSize: Responsive.scaledFontSize(context, 28),
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Food Sales: ₹${totalSales.toStringAsFixed(0)}',
                      style: GoogleFonts.inter(
                        fontSize: Responsive.scaledFontSize(context, 12.5),
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Orders: $ordersCount',
                      style: GoogleFonts.inter(
                        fontSize: Responsive.scaledFontSize(context, 12.5),
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 3. Settlement Breakdown
          Text(
            'Settlement Breakdown',
            style: GoogleFonts.inter(
              fontSize: Responsive.scaledFontSize(context, 15),
              fontWeight: FontWeight.w900,
              color: widget.slateDark,
            ),
          ),
          const SizedBox(height: 10),
          _buildSummaryRow(
            'Food Item Sales (Gross)',
            '₹${totalSales.toStringAsFixed(2)}',
            widget.slateDark,
          ),
          _buildSummaryRow(
            'Platform Commission (${commPercent.toInt()}%)',
            commissionDeduction > 0 ? '-₹${commissionDeduction.toStringAsFixed(2)}' : '-${commPercent.toInt()}%',
            widget.primaryRed,
          ),
          _buildSummaryRow(
            'Net Payable Settlement',
            '₹${netProfit.toStringAsFixed(2)}',
            widget.brandGreen,
          ),
          const SizedBox(height: 22),

          // 4. Settled Orders for this period
          if (filteredOrdersList.isNotEmpty) ...[
            Text(
              'Orders in this Period ($ordersCount)',
              style: GoogleFonts.inter(
                fontSize: Responsive.scaledFontSize(context, 14),
                fontWeight: FontWeight.w900,
                color: widget.slateDark,
              ),
            ),
            const SizedBox(height: 10),
            ...filteredOrdersList.map((o) {
              final String id = (o['id'] ?? '').toString();
              final rawReadable = o['readableId'];
              final String displayId = (rawReadable != null && rawReadable.toString().isNotEmpty)
                  ? '#$rawReadable-R'
                  : '#${id.length > 4 ? id.substring(id.length - 4) : id}-R';
              final num tot = (o['total'] is num) ? (o['total'] as num) : (num.tryParse(o['total']?.toString() ?? '0') ?? 0);
              final dynamic rawItems = o['items'];
              final List items = (rawItems is List) ? rawItems : [];
              double orderFoodSum = 0.0;
              if (items.isNotEmpty) {
                for (final it in items) {
                  final num p = (it['price'] is num) ? (it['price'] as num) : (num.tryParse(it['price']?.toString() ?? '0') ?? 0);
                  final int q = (it['quantity'] is num) ? (it['quantity'] as num).toInt() : (int.tryParse(it['quantity']?.toString() ?? '1') ?? 1);
                  orderFoodSum += (p * q).toDouble();
                }
              } else {
                orderFoodSum = tot.toDouble();
              }
              final String itemsDesc = items.isNotEmpty
                  ? items.map((i) => '${i['quantity'] ?? 1}x ${i['name'] ?? 'Dish'}').join(', ')
                  : 'Food Items';

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: widget.slateBorder),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 1)),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: AppDesignSystem.slate100,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.receipt_long_rounded, size: 18, color: widget.slateDark),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                displayId,
                                style: GoogleFonts.inter(
                                  fontSize: Responsive.scaledFontSize(context, 13.5),
                                  fontWeight: FontWeight.w900,
                                  color: widget.slateDark,
                                ),
                              ),
                              Text(
                                '₹${orderFoodSum.toStringAsFixed(0)}',
                                style: GoogleFonts.inter(
                                  fontSize: Responsive.scaledFontSize(context, 14),
                                  fontWeight: FontWeight.w900,
                                  color: widget.brandGreen,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            itemsDesc,
                            style: GoogleFonts.inter(
                              fontSize: Responsive.scaledFontSize(context, 11.5),
                              color: widget.slateMuted,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(28),
              alignment: Alignment.center,
              child: Column(
                children: [
                  Icon(Icons.receipt_outlined, size: 44, color: widget.slateMuted.withValues(alpha: 0.5)),
                  const SizedBox(height: 10),
                  Text(
                    'No Settled Orders Found',
                    style: GoogleFonts.inter(
                      fontSize: Responsive.scaledFontSize(context, 14),
                      fontWeight: FontWeight.w800,
                      color: widget.slateDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Delivered restaurant orders will appear here.',
                    style: GoogleFonts.inter(
                      fontSize: Responsive.scaledFontSize(context, 12),
                      color: widget.slateMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String title, String val, Color valColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: widget.slateBorder),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: Responsive.scaledFontSize(context, 13),
              fontWeight: FontWeight.w700,
              color: widget.slateDark,
            ),
          ),
          Text(
            val,
            style: GoogleFonts.inter(
              fontSize: Responsive.scaledFontSize(context, 13),
              fontWeight: FontWeight.w800,
              color: valColor,
            ),
          ),
        ],
      ),
    );
  }
}