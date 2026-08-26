import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/design_system.dart';
import '../../widgets/brand_button.dart';

class RestaurantOrderQueueScreen extends StatelessWidget {
  const RestaurantOrderQueueScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final orders = List.generate(6, (i) => {
      'id': '#ORD-${1000 + i}',
      'customer': ['Rahul S.', 'Priya K.', 'Amit V.', 'Neha G.', 'Karan P.', 'Sneha M.'][i],
      'items': ['Cappuccino x2, Chai x1', 'Burger, Fries, Brownie', 'Cold Coffee x2', 'Paneer Roll x2', 'Samosa x4, Chai x2', 'Choco Shake x3'][i],
      'total': [310, 470, 218, 248, 160, 387][i],
      'status': ['pending', 'accepted', 'pending', 'preparing', 'ready', 'pending'][i],
    });

    return Scaffold(
      backgroundColor: AppDesignSystem.background,
      appBar: AppBar(
        backgroundColor: AppDesignSystem.background,
        elevation: 0,
        title: Text('Order Queue', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: AppDesignSystem.textPrimary)),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: orders.length,
        itemBuilder: (context, index) {
          final o = orders[index];
          final statusColor = o['status'] == 'pending' ? AppDesignSystem.warning : o['status'] == 'accepted' ? AppDesignSystem.info : o['status'] == 'preparing' ? AppDesignSystem.cafeAccent : AppDesignSystem.success;
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
                    Text(o['id']?.toString() ?? '', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: AppDesignSystem.textSecondary)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                      child: Text(o['status'].toString().toUpperCase(), style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w800, color: statusColor)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(o['customer']?.toString() ?? '', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppDesignSystem.textPrimary)),
                const SizedBox(height: 4),
                Text(o['items']?.toString() ?? '', style: GoogleFonts.inter(fontSize: 12, color: AppDesignSystem.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: BrandButton(
                        text: 'Reject',
                        fullWidth: true,
                        backgroundColor: AppDesignSystem.danger,
                        textColor: Colors.white,
                        onPressed: () {},
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: BrandButton(
                        text: 'Accept',
                        fullWidth: true,
                        onPressed: () {},
                      ),
                    ),
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