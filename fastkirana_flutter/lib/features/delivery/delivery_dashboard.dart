import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/design_system.dart';
import '../../widgets/brand_button.dart';

class DeliveryDashboard extends ConsumerStatefulWidget {
  const DeliveryDashboard({super.key});

  @override
  ConsumerState<DeliveryDashboard> createState() => _DeliveryDashboardState();
}

class _DeliveryDashboardState extends ConsumerState<DeliveryDashboard> {
  bool _isOnline = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppDesignSystem.background,
      appBar: AppBar(
        backgroundColor: AppDesignSystem.background,
        elevation: 0,
        title: Text(
          'Delivery Dashboard',
          style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: AppDesignSystem.textPrimary),
        ),
        actions: [
          Switch(
            value: _isOnline,
            onChanged: (v) => setState(() => _isOnline = v),
            activeColor: AppDesignSystem.success,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Status Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _isOnline ? [AppDesignSystem.success, AppDesignSystem.accentDark] : [AppDesignSystem.textSecondary, AppDesignSystem.textPrimary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: AppDesignSystem.shadowCard,
              ),
              child: Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Icon(_isOnline ? Icons.delivery_dining_rounded : Icons.do_not_disturb_rounded, size: 32, color: Colors.white),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_isOnline ? 'You are online' : 'You are offline', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
                        Text(_isOnline ? 'You can receive orders' : 'Turn on to receive orders', style: GoogleFonts.inter(fontSize: 12, color: Colors.white.withOpacity(0.9))),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Today's Stats
            Row(
              children: [
                _statCard('Orders', '12', Icons.shopping_bag_rounded, AppDesignSystem.primary),
                const SizedBox(width: 12),
                _statCard('Earnings', '₹480', Icons.currency_rupee_rounded, AppDesignSystem.success),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _statCard('Distance', '38 km', Icons.route_rounded, AppDesignSystem.info),
                const SizedBox(width: 12),
                _statCard('Rating', '4.8', Icons.star_rounded, AppDesignSystem.warning),
              ],
            ),

            const SizedBox(height: 24),

            // Available Orders
            Text(
              'Available Orders',
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: AppDesignSystem.textPrimary),
            ),
            const SizedBox(height: 12),

            _orderCard(
              'ORD-2024-001',
              'Aman Kumar',
              '123, Green Park, Ghatampur',
              '₹45 commission',
              '5 km',
            ),
            const SizedBox(height: 12),
            _orderCard(
              'ORD-2024-002',
              'Priya Sharma',
              '45, Main Road, Sector 12',
              '₹55 commission',
              '3 km',
            ),
          ],
        ),
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
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
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(height: 12),
            Text(value, style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w800, color: AppDesignSystem.textPrimary)),
            Text(label, style: GoogleFonts.inter(fontSize: 12, color: AppDesignSystem.textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _orderCard(String id, String customer, String address, String earning, String distance) {
    return Container(
      padding: const EdgeInsets.all(14),
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
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppDesignSystem.warning.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(id, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: AppDesignSystem.warning)),
              ),
              const Spacer(),
              Text(distance, style: GoogleFonts.inter(fontSize: 12, color: AppDesignSystem.textSecondary)),
            ],
          ),
          const SizedBox(height: 10),
          Text(customer, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppDesignSystem.textPrimary)),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.location_on_outlined, size: 12, color: AppDesignSystem.textSecondary),
              const SizedBox(width: 4),
              Expanded(
                child: Text(address, style: GoogleFonts.inter(fontSize: 12, color: AppDesignSystem.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: BrandButton(
                  text: 'Accept ($earning)',
                  onPressed: () {},
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppDesignSystem.borderLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.navigation_rounded, size: 18, color: AppDesignSystem.primary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}