import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/design_system.dart';

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppDesignSystem.background,
      appBar: AppBar(
        backgroundColor: AppDesignSystem.surface,
        elevation: 0,
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [AppDesignSystem.primary, AppDesignSystem.primaryDark]),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.admin_panel_settings_rounded, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 12),
            Text('Admin Dashboard', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: AppDesignSystem.textPrimary)),
          ],
        ),
        actions: [
          IconButton(icon: Icon(Icons.notifications_none_rounded, color: AppDesignSystem.textPrimary), onPressed: () {}),
          IconButton(icon: Icon(Icons.settings_rounded, color: AppDesignSystem.textPrimary), onPressed: () {}),
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
                gradient: LinearGradient(colors: [AppDesignSystem.primary, AppDesignSystem.primaryDark]),
                borderRadius: BorderRadius.circular(16),
                boxShadow: AppDesignSystem.shadowCard,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Today\'s Performance', style: GoogleFonts.inter(fontSize: 14, color: Colors.white.withOpacity(0.9))),
                  const SizedBox(height: 4),
                  Text('₹24,580', style: GoogleFonts.poppins(fontSize: 32, fontWeight: FontWeight.w800, color: Colors.white)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.trending_up_rounded, color: Colors.white, size: 14),
                      const SizedBox(width: 4),
                      Text('+12.5% from yesterday', style: GoogleFonts.inter(fontSize: 12, color: Colors.white)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Quick Stats
            Row(
              children: [
                _statCard('Orders', '142', Icons.shopping_bag_rounded, AppDesignSystem.primary, '+8 today'),
                const SizedBox(width: 12),
                _statCard('Revenue', '₹24K', Icons.currency_rupee_rounded, AppDesignSystem.success, '+12%'),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _statCard('Customers', '8.4K', Icons.people_rounded, AppDesignSystem.info, '+24 new'),
                const SizedBox(width: 12),
                _statCard('Pending', '12', Icons.pending_actions_rounded, AppDesignSystem.warning, 'urgent'),
              ],
            ),
            const SizedBox(height: 16),

            // Charts placeholder
            Container(
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
                  Text('Weekly Sales', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: AppDesignSystem.textPrimary)),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 120,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [40, 70, 55, 90, 65, 110, 95].asMap().entries.map((e) => Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Container(
                                height: e.value.toDouble(),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [AppDesignSystem.primary, AppDesignSystem.primaryDark],
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                  ),
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(['M', 'T', 'W', 'T', 'F', 'S', 'S'][e.key], style: GoogleFonts.inter(fontSize: 9, color: AppDesignSystem.textSecondary)),
                            ],
                          ),
                        ),
                      )).toList(),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Quick Actions
            Text('Quick Actions', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: AppDesignSystem.textPrimary)),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.85,
              children: [
                _actionBtn('Products', Icons.inventory_2_rounded, AppDesignSystem.primary),
                _actionBtn('Orders', Icons.shopping_bag_rounded, AppDesignSystem.success),
                _actionBtn('Customers', Icons.people_rounded, AppDesignSystem.info),
                _actionBtn('Coupons', Icons.local_offer_rounded, AppDesignSystem.warning),
                _actionBtn('Banners', Icons.image_rounded, AppDesignSystem.cafeAccent),
                _actionBtn('Reports', Icons.bar_chart_rounded, AppDesignSystem.primary),
                _actionBtn('Delivery', Icons.delivery_dining_rounded, AppDesignSystem.accent),
                _actionBtn('Settings', Icons.settings_rounded, AppDesignSystem.textSecondary),
              ],
            ),
            const SizedBox(height: 16),
            // Recent Orders
            Text('Recent Orders', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: AppDesignSystem.textPrimary)),
            const SizedBox(height: 12),
            _orderCard('ORD-001', 'Aman Kumar', '₹450', 'CONFIRMED', AppDesignSystem.info),
            const SizedBox(height: 8),
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

  Widget _actionBtn(String label, IconData icon, Color color) {
    return Container(
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