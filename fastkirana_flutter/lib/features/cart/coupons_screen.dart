import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/design_system.dart';
import '../../widgets/brand_button.dart';

class CouponsScreen extends StatelessWidget {
  const CouponsScreen({super.key});

  final List<Map<String, String>> _coupons = const [
    {
      'code': 'FAST50',
      'discount': 'FLAT ₹50 OFF',
      'desc': 'Applicable on orders above ₹299. Valid for today.',
      'tag': 'BEST SAVINGS',
    },
    {
      'code': 'FREEDEL',
      'discount': 'FREE DELIVERY',
      'desc': 'Get zero delivery fee on orders above ₹149.',
      'tag': 'POPULAR',
    },
    {
      'code': 'KIRANA100',
      'discount': 'FLAT ₹100 OFF',
      'desc': 'Valid on monthly grocery staples order above ₹999.',
      'tag': 'MEGA SAVINGS',
    },
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
          'Apply Vouchers & Coupons',
          style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: AppDesignSystem.textPrimary),
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _coupons.length,
        itemBuilder: (context, index) {
          final item = _coupons[index];
          return Container(
            margin: const EdgeInsets.only(bottom: 14),
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppDesignSystem.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppDesignSystem.primary.withOpacity(0.3)),
                      ),
                      child: Text(
                        item['code']!,
                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: AppDesignSystem.primary, letterSpacing: 0.5),
                      ),
                    ),
                    Text(
                      item['tag']!,
                      style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: AppDesignSystem.accent),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  item['discount']!,
                  style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: AppDesignSystem.textPrimary),
                ),
                const SizedBox(height: 4),
                Text(
                  item['desc']!,
                  style: GoogleFonts.inter(fontSize: 12, color: AppDesignSystem.textSecondary, height: 1.3),
                ),
                const SizedBox(height: 14),
                BrandButton(
                  text: 'Apply Coupon',
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Coupon ${item['code']} applied successfully!')),
                    );
                    Navigator.pop(context, item['code']);
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
