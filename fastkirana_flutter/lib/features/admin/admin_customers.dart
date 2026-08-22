import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/design_system.dart';

class AdminCustomersScreen extends StatelessWidget {
  const AdminCustomersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final customers = List.generate(12, (i) => {
      'name': ['Aman Kumar', 'Priya Sharma', 'Rohit Verma', 'Sneha Malhotra', 'Karan Patel', 'Neha Gupta'][i % 6],
      'phone': '+91 98${10000000 + i * 1111111}',
      'orders': i + 1,
      'spent': '₹${(i + 1) * 500}',
      'joined': 'Jan ${i + 1}',
    });

    return Scaffold(
      backgroundColor: AppDesignSystem.background,
      appBar: AppBar(
        backgroundColor: AppDesignSystem.background,
        elevation: 0,
        title: Text('Customers', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: AppDesignSystem.textPrimary)),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: customers.length,
        itemBuilder: (context, index) {
          final c = customers[index];
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
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [AppDesignSystem.primary, AppDesignSystem.primaryDark]),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Center(child: Text((c['name'] as String).split(' ').map((w) => w[0]).join(), style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white))),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c['name'] as String, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppDesignSystem.textPrimary)),
                      Text(c['phone'] as String, style: GoogleFonts.inter(fontSize: 11, color: AppDesignSystem.textSecondary)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(c['spent'] as String, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: AppDesignSystem.textPrimary)),
                    Text('${c['orders']} orders', style: GoogleFonts.inter(fontSize: 11, color: AppDesignSystem.textSecondary)),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}