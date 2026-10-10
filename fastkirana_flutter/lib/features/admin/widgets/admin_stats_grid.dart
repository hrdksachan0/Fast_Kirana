import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/design_system.dart';
import 'admin_stat_card.dart';

/// Summary Metric Grid for Admin Orders Dashboard (with smooth expand/collapse)
class AdminStatsGrid extends StatefulWidget {
  final double displayTodaySales;
  final double displayTodayNetSales;
  final int displayTodayOrdersCount;
  final int displayActiveOrderCount;
  final double displayTodayDeliveryFee;
  final double displayTodayPackagingFee;

  const AdminStatsGrid({
    super.key,
    required this.displayTodaySales,
    required this.displayTodayNetSales,
    required this.displayTodayOrdersCount,
    required this.displayActiveOrderCount,
    required this.displayTodayDeliveryFee,
    required this.displayTodayPackagingFee,
  });

  @override
  State<AdminStatsGrid> createState() => _AdminStatsGridState();
}

class _AdminStatsGridState extends State<AdminStatsGrid> {
  bool _isCollapsed = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header Row with Mini Summary & Collapse/Expand Toggle
          InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _isCollapsed = !_isCollapsed);
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppDesignSystem.green50,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.analytics_outlined, size: 14, color: AppDesignSystem.emerald600),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'DAILY OVERVIEW',
                    style: GoogleFonts.inter(
                      fontSize: Responsive.scaledFontSize(context, 10.5),
                      fontWeight: FontWeight.w900,
                      color: AppDesignSystem.slate500,
                      letterSpacing: 0.8,
                    ),
                  ),
                  if (_isCollapsed) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '₹${widget.displayTodaySales.toInt()} • ${widget.displayTodayOrdersCount} orders • ${widget.displayActiveOrderCount} live',
                        style: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 11),
                          fontWeight: FontWeight.w700,
                          color: AppDesignSystem.slate700,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ] else
                    const Spacer(),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _isCollapsed ? 'Show Stats' : 'Hide Stats',
                        style: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 10.5),
                          fontWeight: FontWeight.w700,
                          color: AppDesignSystem.slate500,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        _isCollapsed ? Icons.keyboard_arrow_down_rounded : Icons.keyboard_arrow_up_rounded,
                        size: 18,
                        color: AppDesignSystem.slate500,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          if (!_isCollapsed) ...[
            const SizedBox(height: 8),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Card 1: Today's Sales
                  Expanded(
                    child: AdminStatCard(
                      title: "Today's Sales",
                      value: '₹${widget.displayTodaySales.toInt()}',
                      subtitle: (widget.displayTodayDeliveryFee > 0 || widget.displayTodayPackagingFee > 0)
                          ? 'Incl. ₹${widget.displayTodayDeliveryFee.toInt()} del + ₹${widget.displayTodayPackagingFee.toInt()} pack'
                          : 'Gross order total',
                      icon: Icons.currency_rupee_rounded,
                      iconColor: AppDesignSystem.emerald600,
                      bgColor: AppDesignSystem.green50,
                      borderColor: AppDesignSystem.emerald200,
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Card 2: Net Sales
                  Expanded(
                    child: AdminStatCard(
                      title: "Net Sales",
                      value: '₹${widget.displayTodayNetSales.toInt()}',
                      subtitle: 'Delivered net of refunds',
                      icon: Icons.trending_up_rounded,
                      iconColor: AppDesignSystem.teal600,
                      bgColor: AppDesignSystem.teal50,
                      borderColor: AppDesignSystem.teal300,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Card 3: Today's Orders
                  Expanded(
                    child: AdminStatCard(
                      title: "Today's Orders",
                      value: '${widget.displayTodayOrdersCount}',
                      subtitle: 'Total placed today',
                      icon: Icons.shopping_bag_outlined,
                      iconColor: AppDesignSystem.blue600,
                      bgColor: AppDesignSystem.blue50,
                      borderColor: AppDesignSystem.blue200,
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Card 4: Active Orders
                  Expanded(
                    child: AdminStatCard(
                      title: 'Active Orders',
                      value: '${widget.displayActiveOrderCount}',
                      subtitle: 'In fulfillment now',
                      icon: Icons.bolt_rounded,
                      iconColor: AppDesignSystem.orange600,
                      bgColor: AppDesignSystem.orange50,
                      borderColor: AppDesignSystem.orange300,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
          ],
        ],
      ),
    );
  }
}
