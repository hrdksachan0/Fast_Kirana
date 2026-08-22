import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/design_system.dart';

class AdminOrdersScreen extends StatelessWidget {
  const AdminOrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final orders = List.generate(15, (i) => {
      'id': 'ORD-${1000 + i}',
      'customer': ['Aman K.', 'Priya S.', 'Rohit V.', 'Sneha M.', 'Karan P.'][i % 5],
      'amount': ['₹450', '₹1,250', '₹680', '₹920', '₹350'][i % 5],
      'status': ['PENDING', 'CONFIRMED', 'PACKED', 'OUT', 'DELIVERED'][i % 5],
      'time': '${i + 1}m ago',
    });

    return Scaffold(
      backgroundColor: AppDesignSystem.background,
      appBar: AppBar(
        backgroundColor: AppDesignSystem.background,
        elevation: 0,
        title: Text('Orders', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: AppDesignSystem.textPrimary)),
      ),
      body: Column(
        children: [
          // Filter tabs
          Padding(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ['All (142)', 'Pending (12)', 'Confirmed (24)', 'Packed (18)', 'Out (8)', 'Delivered (80)']
                    .asMap().entries.map((e) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: e.key == 0 ? AppDesignSystem.primary : AppDesignSystem.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: e.key == 0 ? AppDesignSystem.primary : AppDesignSystem.borderLight),
                        ),
                        child: Text(e.value, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: e.key == 0 ? Colors.white : AppDesignSystem.textPrimary)),
                      ),
                    )).toList(),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: orders.length,
              itemBuilder: (context, index) {
                final o = orders[index];
                final colors = [AppDesignSystem.warning, AppDesignSystem.info, AppDesignSystem.primary, AppDesignSystem.cafeAccent, AppDesignSystem.success];
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppDesignSystem.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppDesignSystem.borderLight),
                    boxShadow: AppDesignSystem.shadowSm,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(o['id'] as String, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: AppDesignSystem.textPrimary)),
                            Text(o['customer'] as String, style: GoogleFonts.inter(fontSize: 12, color: AppDesignSystem.textSecondary)),
                            const SizedBox(height: 4),
                            Text(o['time'] as String, style: GoogleFonts.inter(fontSize: 10, color: AppDesignSystem.textMuted)),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(o['amount'] as String, style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w800, color: AppDesignSystem.textPrimary)),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: colors[index % 5].withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                            child: Text(o['status'] as String, style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w800, color: colors[index % 5])),
                          ),
                        ],
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppDesignSystem.textMuted),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}