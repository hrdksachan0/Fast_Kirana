import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/design_system.dart';

class RestaurantMenuManagementScreen extends StatelessWidget {
  const RestaurantMenuManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final items = List.generate(10, (i) => {
      'name': ['Cappuccino', 'Masala Chai', 'Veg Burger', 'French Fries', 'Cold Coffee', 'Brownie', 'Paneer Roll', 'Choco Shake', 'Samosa', 'Pasta'][i],
      'price': [120, 30, 89, 79, 99, 149, 89, 129, 20, 149][i],
      'available': i != 4,
      'category': ['Coffee', 'Beverages', 'Snacks', 'Snacks', 'Coffee', 'Desserts', 'Snacks', 'Beverages', 'Snacks', 'Snacks'][i],
    });

    return Scaffold(
      backgroundColor: AppDesignSystem.background,
      appBar: AppBar(
        backgroundColor: AppDesignSystem.background,
        elevation: 0,
        title: Text('Menu Management', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 18), fontWeight: FontWeight.w800, color: AppDesignSystem.textPrimary)),
        actions: [IconButton(icon: Icon(Icons.add_rounded, color: AppDesignSystem.primary), onPressed: () {})],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(color: AppDesignSystem.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppDesignSystem.borderLight)),
                    child: Row(
                      children: [
                        Icon(Icons.search_rounded, size: 18, color: AppDesignSystem.textMuted),
                        const SizedBox(width: 8),
                        Text('Search items...', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 13), color: AppDesignSystem.textMuted)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
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
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(color: AppDesignSystem.background, borderRadius: BorderRadius.circular(10)),
                        child: Center(child: Text(['☕', '🍵', '🍔', '🍟', '🥤', '🍰', '🌯', '🍫', '🥟', '🍝'][index], style: const TextStyle(fontSize: Responsive.scaledFontSize(context, 24)))),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item['name']?.toString() ?? '', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 14), fontWeight: FontWeight.w700, color: AppDesignSystem.textPrimary)),
                            Text(item['category']?.toString() ?? '', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 11), color: AppDesignSystem.textSecondary)),
                          ],
                        ),
                      ),
                      Text('₹${item['price']}', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 14), fontWeight: FontWeight.w800, color: AppDesignSystem.textPrimary)),
                      const SizedBox(width: 12),
                      Switch(
                        value: item['available'] as bool? ?? true,
                        onChanged: (v) {},
                        activeColor: AppDesignSystem.success,
                      ),
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