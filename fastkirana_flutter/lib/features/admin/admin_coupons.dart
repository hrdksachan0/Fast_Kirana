import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/design_system.dart';
import '../../widgets/brand_button.dart';

class AdminCouponsScreen extends StatelessWidget {
  const AdminCouponsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final coupons = List.generate(6, (i) => {
      'code': ['WELCOME50', 'FREEDEL', 'KIRANA100', 'CAFE20', 'WEEKEND30', 'BULK200'][i],
      'discount': ['₹50 OFF', 'Free Delivery', '₹100 OFF', '20% OFF', '30% OFF', '₹200 OFF'][i],
      'min': ['₹199', '₹0', '₹999', '₹299', '₹399', '₹1499'][i],
      'used': [1200, 3500, 800, 450, 900, 200][i],
      'active': i != 2,
    });

    return Scaffold(
      backgroundColor: AppDesignSystem.background,
      appBar: AppBar(
        backgroundColor: AppDesignSystem.background,
        elevation: 0,
        title: Text('Coupons Management', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: AppDesignSystem.textPrimary)),
        actions: [
          IconButton(icon: Icon(Icons.add_rounded, color: AppDesignSystem.primary), onPressed: () {}),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: coupons.length,
        itemBuilder: (context, index) {
          final c = coupons[index];
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
                      Row(
                        children: [
                          Text(c['code'] as String, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: AppDesignSystem.textPrimary)),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: (c['active'] as bool) ? AppDesignSystem.success.withOpacity(0.1) : AppDesignSystem.danger.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text((c['active'] as bool) ? 'ACTIVE' : 'INACTIVE', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w800, color: (c['active'] as bool) ? AppDesignSystem.success : AppDesignSystem.danger)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text('${c['discount']} • Min: ${c['min']}', style: GoogleFonts.inter(fontSize: 12, color: AppDesignSystem.textSecondary)),
                      const SizedBox(height: 4),
                      Text('Used: ${c['used']}', style: GoogleFonts.inter(fontSize: 11, color: AppDesignSystem.textMuted)),
                    ],
                  ),
                ),
                IconButton(icon: Icon(Icons.edit_outlined, color: AppDesignSystem.primary), onPressed: () {}),
              ],
            ),
          );
        },
      ),
    );
  }
}