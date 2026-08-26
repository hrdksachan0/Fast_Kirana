import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_bounceable/flutter_bounceable.dart';
import '../../core/theme/design_system.dart';
import '../../core/routes/page_transitions.dart';
import 'admin_products.dart';
import 'admin_orders_list.dart';
import 'admin_customers.dart';
import 'admin_coupons.dart';
import 'admin_banners.dart';
import 'admin_reports.dart';
import 'admin_settings.dart';

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppDesignSystem.background,
      appBar: AppBar(
        backgroundColor: AppDesignSystem.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppDesignSystem.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [AppDesignSystem.primary, AppDesignSystem.primaryDark]),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.admin_panel_settings_rounded, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 12),
            Text('Admin & Staff Hub', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: AppDesignSystem.textPrimary)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_rounded, color: AppDesignSystem.textPrimary),
            onPressed: () => Navigator.push(context, FadeSlideRoute(page: const AdminSettingsScreen())),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Banner
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [AppDesignSystem.primary, AppDesignSystem.primaryDark]),
                borderRadius: BorderRadius.circular(16),
                boxShadow: AppDesignSystem.shadowCard,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Ghatampur Hub · Live Overview', style: GoogleFonts.inter(fontSize: 13, color: Colors.white.withOpacity(0.9))),
                  const SizedBox(height: 4),
                  Text('₹24,580', style: GoogleFonts.poppins(fontSize: 30, fontWeight: FontWeight.w800, color: Colors.white)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.trending_up_rounded, color: Colors.white, size: 14),
                      const SizedBox(width: 4),
                      Text('100% Synced with Supabase', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Quick Stats
            Row(
              children: [
                _statCard('Orders', '142', Icons.shopping_bag_rounded, AppDesignSystem.primary, 'Live'),
                const SizedBox(width: 12),
                _statCard('Revenue', '₹24.5K', Icons.currency_rupee_rounded, AppDesignSystem.success, '+12%'),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _statCard('Customers', '8.4K', Icons.people_rounded, AppDesignSystem.info, 'Active'),
                const SizedBox(width: 12),
                _statCard('Stock', '190+ Items', Icons.inventory_2_rounded, AppDesignSystem.warning, 'Supabase'),
              ],
            ),
            const SizedBox(height: 20),

            // Quick Actions
            Text('Quick Controls', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: AppDesignSystem.textPrimary)),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.85,
              children: [
                _actionBtn(context, 'Products', Icons.inventory_2_rounded, AppDesignSystem.primary, () {
                  Navigator.push(context, FadeSlideRoute(page: const AdminProductsScreen()));
                }),
                _actionBtn(context, 'Orders', Icons.shopping_bag_rounded, AppDesignSystem.success, () {
                  Navigator.push(context, FadeSlideRoute(page: const AdminOrdersScreen()));
                }),
                _actionBtn(context, 'Customers', Icons.people_rounded, AppDesignSystem.info, () {
                  Navigator.push(context, FadeSlideRoute(page: const AdminCustomersScreen()));
                }),
                _actionBtn(context, 'Coupons', Icons.local_offer_rounded, AppDesignSystem.warning, () {
                  Navigator.push(context, FadeSlideRoute(page: const AdminCouponsScreen()));
                }),
                _actionBtn(context, 'Banners', Icons.image_rounded, AppDesignSystem.cafeAccent, () {
                  Navigator.push(context, FadeSlideRoute(page: const AdminBannersScreen()));
                }),
                _actionBtn(context, 'Reports', Icons.bar_chart_rounded, AppDesignSystem.primary, () {
                  Navigator.push(context, FadeSlideRoute(page: const AdminReportsScreen()));
                }),
                _actionBtn(context, 'Orders Pipeline', Icons.delivery_dining_rounded, AppDesignSystem.accent, () {
                  Navigator.push(context, FadeSlideRoute(page: const AdminOrdersScreen()));
                }),
                _actionBtn(context, 'Settings', Icons.settings_rounded, AppDesignSystem.textSecondary, () {
                  Navigator.push(context, FadeSlideRoute(page: const AdminSettingsScreen()));
                }),
              ],
            ),
            const SizedBox(height: 20),

            // Recent Orders
            _orderCard('ORD-002', 'Priya S.', '₹1,250', 'PENDING', AppDesignSystem.warning),
            const SizedBox(height: 8),
            _orderCard('ORD-003', 'Rohit V.', '₹680', 'DELIVERED', AppDesignSystem.success),
          ],
        ),
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color, String trend) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppDesignSystem.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppDesignSystem.borderLight),
          boxShadow: AppDesignSystem.shadowSm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                  child: Icon(icon, size: 18, color: color),
                ),
                Text(trend, style: GoogleFonts.inter(fontSize: 10, color: AppDesignSystem.textMuted)),
              ],
            ),
            const SizedBox(height: 12),
            Text(value, style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w800, color: AppDesignSystem.textPrimary)),
            Text(label, style: GoogleFonts.inter(fontSize: 12, color: AppDesignSystem.textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _actionBtn(BuildContext context, String label, IconData icon, Color color, VoidCallback onTap) {
    return Bounceable(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        decoration: BoxDecoration(
          color: AppDesignSystem.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppDesignSystem.borderLight),
          boxShadow: AppDesignSystem.shadowSm,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 8),
            Text(label, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: AppDesignSystem.textPrimary)),
          ],
        ),
      ),
    );
  }

  Widget _orderCard(String id, String name, String amount, String status, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppDesignSystem.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppDesignSystem.borderLight),
        boxShadow: AppDesignSystem.shadowSm,
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: AppDesignSystem.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
            child: Center(child: Text(id.split('-').last, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: AppDesignSystem.primary))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppDesignSystem.textPrimary)),
                Text(id, style: GoogleFonts.inter(fontSize: 11, color: AppDesignSystem.textSecondary)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(amount, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: AppDesignSystem.textPrimary)),
              Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                child: Text(status, style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w800, color: color)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}