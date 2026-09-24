import 'package:flutter/material.dart';
import '../../../../core/theme/design_system.dart';
import 'admin_stat_card.dart';

/// 2x2 Summary Metric Grid for Admin Orders Dashboard
class AdminStatsGrid extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        children: [
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Card 1: Today's Sales
                Expanded(
                  child: AdminStatCard(
                    title: "Today's Sales",
                    value: '₹${displayTodaySales.toInt()}',
                    subtitle: (displayTodayDeliveryFee > 0 || displayTodayPackagingFee > 0)
                        ? 'Incl. ₹${displayTodayDeliveryFee.toInt()} del + ₹${displayTodayPackagingFee.toInt()} pack'
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
                    value: '₹${displayTodayNetSales.toInt()}',
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
                    value: '$displayTodayOrdersCount',
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
                    value: '$displayActiveOrderCount',
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
        ],
      ),
    );
  }
}
