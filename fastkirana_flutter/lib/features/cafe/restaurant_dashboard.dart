import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/design_system.dart';
import '../../widgets/brand_button.dart';

class RestaurantDashboard extends StatelessWidget {
  const RestaurantDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppDesignSystem.background,
      appBar: AppBar(
        backgroundColor: AppDesignSystem.surface,
        elevation: 0,
        title: Row(
          children: [
            Text('☕', style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 10),
            Text('Chai Wai', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: AppDesignSystem.textPrimary)),
          ],
        ),
        actions: [IconButton(icon: Icon(Icons.settings_rounded, color: AppDesignSystem.textPrimary), onPressed: () {})],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Today's stats
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [AppDesignSystem.cafeAccent, const Color(0xFFEA580C)]),
                borderRadius: BorderRadius.circular(16),
                boxShadow: AppDesignSystem.shadowCard,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _rStat('Orders', '48', '+6 today'),
                  _rStat('Revenue', '₹3.2K', '+12%'),
                  _rStat('Rating', '4.5', '⭐'),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text('Pending Orders', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: AppDesignSystem.textPrimary)),
            const SizedBox(height: 12),
            ...List.generate(3, (i) {
              final items = [['Cappuccino x2', 'Masala Chai x1'], ['Veg Burger x2', 'French Fries x1', 'Brownie x1'], ['Paneer Roll x1', 'Cold Coffee x1']][i];
              final customer = ['Rahul S.', 'Priya K.', 'Amit V.'][i];
              final total = [310, 470, 218][i];
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
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
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('#ORD-${1000 + i}', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: AppDesignSystem.textPrimary)),
                        Text('₹$total', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: AppDesignSystem.textPrimary)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(customer, style: GoogleFonts.inter(fontSize: 13, color: AppDesignSystem.textSecondary)),
                    Text(items.join(', '), style: GoogleFonts.inter(fontSize: 12, color: AppDesignSystem.textMuted), maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {},
                            style: ElevatedButton.styleFrom(backgroundColor: AppDesignSystem.danger, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 10)),
                            child: Text('Reject', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {},
                            style: ElevatedButton.styleFrom(backgroundColor: AppDesignSystem.success, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 10)),
                            child: Text('Accept', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 16),
            // Table bookings
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: AppDesignSystem.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppDesignSystem.borderLight), boxShadow: AppDesignSystem.shadowSm),
              child: Row(
                children: [
                  Icon(Icons.event_rounded, color: AppDesignSystem.cafeAccent, size: 20),
                  const SizedBox(width: 12),
                  Expanded(child: Text('3 Table Bookings Today', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppDesignSystem.textPrimary))),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: AppDesignSystem.cafeAccent, borderRadius: BorderRadius.circular(8)),
                    child: Text('VIEW', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _rStat(String label, String value, String trend) {
    return Column(
      children: [
        Text(value, style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
        Text(label, style: GoogleFonts.inter(fontSize: 11, color: Colors.white.withOpacity(0.9))),
        Text(trend, style: GoogleFonts.inter(fontSize: 10, color: Colors.white)),
      ],
    );
  }
}