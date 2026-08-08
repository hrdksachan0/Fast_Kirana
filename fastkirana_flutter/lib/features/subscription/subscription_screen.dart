import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/design_system.dart';
import '../../widgets/brand_button.dart';

class SubscriptionScreen extends StatelessWidget {
  const SubscriptionScreen({super.key});

  final List<Map<String, dynamic>> _subscriptions = const [
    {'name': 'Daily Milk Delivery', 'icon': '🥛', 'frequency': 'Daily', 'price': '₹28/day', 'status': 'active'},
    {'name': 'Bread Subscription', 'icon': '🍞', 'frequency': 'Daily', 'price': '₹35/day', 'status': 'paused'},
    {'name': 'Weekly Groceries', 'icon': '🛒', 'frequency': 'Weekly', 'price': '₹499/week', 'status': 'active'},
    {'name': 'Eggs Daily', 'icon': '🥚', 'frequency': 'Daily', 'price': '₹60/day', 'status': 'active'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppDesignSystem.background,
      appBar: AppBar(
        backgroundColor: AppDesignSystem.background,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'My Subscriptions',
          style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: AppDesignSystem.textPrimary),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header Banner
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppDesignSystem.primary, AppDesignSystem.primaryDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: AppDesignSystem.shadowCard,
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.autorenew_rounded, size: 28, color: Colors.white),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('4 Active Subscriptions', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
                      const SizedBox(height: 4),
                      Text('Save up to 15% on daily essentials', style: GoogleFonts.inter(fontSize: 12, color: Colors.white.withOpacity(0.9))),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          Text(
            'Active Subscriptions',
            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: AppDesignSystem.textPrimary),
          ),
          const SizedBox(height: 12),

          ..._subscriptions.map((sub) => _buildSubCard(sub)),

          const SizedBox(height: 24),

          // Add new subscription
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppDesignSystem.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppDesignSystem.borderLight, style: BorderStyle.solid),
              boxShadow: AppDesignSystem.shadowSm,
            ),
            child: Column(
              children: [
                Icon(Icons.add_circle_outline_rounded, size: 48, color: AppDesignSystem.primary),
                const SizedBox(height: 12),
                Text('Add New Subscription', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: AppDesignSystem.textPrimary)),
                const SizedBox(height: 4),
                Text('Set daily/weekly delivery for essentials', style: GoogleFonts.inter(fontSize: 12, color: AppDesignSystem.textSecondary), textAlign: TextAlign.center),
                const SizedBox(height: 16),
                BrandButton(
                  text: 'Browse Products',
                  fullWidth: false,
                  onPressed: () {},
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubCard(Map<String, dynamic> sub) {
    final isActive = sub['status'] == 'active';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppDesignSystem.background,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(child: Text(sub['icon'], style: const TextStyle(fontSize: 32))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(sub['name'], style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppDesignSystem.textPrimary)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isActive ? AppDesignSystem.success.withOpacity(0.1) : AppDesignSystem.warning.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        sub['status'].toString().toUpperCase(),
                        style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w800, color: isActive ? AppDesignSystem.success : AppDesignSystem.warning),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text('${sub['frequency']} • ${sub['price']}', style: GoogleFonts.inter(fontSize: 12, color: AppDesignSystem.textSecondary)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _smallBtn('Skip', AppDesignSystem.textSecondary, () {}),
                    const SizedBox(width: 8),
                    _smallBtn('Modify', AppDesignSystem.primary, () {}),
                    const SizedBox(width: 8),
                    _smallBtn('Cancel', AppDesignSystem.danger, () {}),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _smallBtn(String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(label, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: color)),
      ),
    );
  }
}