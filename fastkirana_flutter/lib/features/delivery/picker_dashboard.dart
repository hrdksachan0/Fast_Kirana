import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/design_system.dart';

class PickerDashboard extends StatelessWidget {
  const PickerDashboard({super.key});

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
                gradient: LinearGradient(colors: [AppDesignSystem.accent, AppDesignSystem.accentDark]),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.shopping_cart_rounded, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 12),
            Text('Picker Dashboard', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: AppDesignSystem.textPrimary)),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Stats
          Row(
            children: [
              _statCard('Pending', '8', AppDesignSystem.warning),
              const SizedBox(width: 12),
              _statCard('Picked Today', '24', AppDesignSystem.success),
            ],
          ),
          const SizedBox(height: 16),
          // Pick List
          Text('Active Pick Lists', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: AppDesignSystem.textPrimary)),
          const SizedBox(height: 12),
          ...List.generate(3, (i) {
            final orderNum = 'ORD-${1000 + i}';
            final itemCount = [4, 7, 3][i];
            final progress = [0.5, 0.25, 0.7][i];
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
                      Text(orderNum, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: AppDesignSystem.textPrimary)),
                      Text('${itemCount} items', style: GoogleFonts.inter(fontSize: 12, color: AppDesignSystem.textSecondary)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    height: 6,
                    decoration: BoxDecoration(color: AppDesignSystem.borderLight, borderRadius: BorderRadius.circular(3)),
                    child: FractionallySizedBox(
                      widthFactor: progress,
                      alignment: Alignment.centerLeft,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [AppDesignSystem.success, AppDesignSystem.accent]),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.location_on_outlined, size: 14, color: AppDesignSystem.textSecondary),
                      const SizedBox(width: 4),
                      Text('Aisle ${i + 3}', style: GoogleFonts.inter(fontSize: 12, color: AppDesignSystem.textSecondary)),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: AppDesignSystem.success, borderRadius: BorderRadius.circular(8)),
                        child: Text('PICK', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white)),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _statCard(String label, String value, Color color) {
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
            Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Icon(Icons.bar_chart_rounded, color: color, size: 18)),
            const SizedBox(height: 12),
            Text(value, style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w800, color: AppDesignSystem.textPrimary)),
            Text(label, style: GoogleFonts.inter(fontSize: 12, color: AppDesignSystem.textSecondary)),
          ],
        ),
      ),
    );
  }
}