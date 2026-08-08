import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/design_system.dart';
import '../../widgets/brand_button.dart';

class AdminProductsScreen extends StatelessWidget {
  const AdminProductsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final products = List.generate(12, (i) => {
      'name': ['Fresh Tomatoes', 'Amul Milk', 'Bread', 'Eggs', 'Rice 5kg', 'Sugar 1kg', 'Tea Powder', 'Coffee', 'Biscuits', 'Soap', 'Shampoo', 'Oil 1L'][i],
      'price': [45, 28, 35, 60, 450, 40, 120, 200, 25, 30, 180, 150][i],
      'stock': [120, 50, 8, 200, 25, 80, 30, 45, 60, 100, 25, 40][i],
      'lowStock': [false, false, true, false, false, false, false, false, false, false, true, false][i],
    });

    return Scaffold(
      backgroundColor: AppDesignSystem.background,
      appBar: AppBar(
        backgroundColor: AppDesignSystem.background,
        elevation: 0,
        title: Text('Products', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: AppDesignSystem.textPrimary)),
        actions: [
          IconButton(icon: Icon(Icons.add_rounded, color: AppDesignSystem.primary), onPressed: () {}),
        ],
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
                    decoration: BoxDecoration(
                      color: AppDesignSystem.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppDesignSystem.borderLight),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.search_rounded, size: 18, color: AppDesignSystem.textMuted),
                        const SizedBox(width: 8),
                        Text('Search products...', style: GoogleFonts.inter(fontSize: 13, color: AppDesignSystem.textMuted)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AppDesignSystem.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(14)),
                  child: Icon(Icons.tune_rounded, color: AppDesignSystem.primary, size: 18),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: products.length,
              itemBuilder: (context, index) {
                final p = products[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppDesignSystem.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: p['lowStock'] ? AppDesignSystem.warning.withOpacity(0.5) : AppDesignSystem.borderLight),
                    boxShadow: AppDesignSystem.shadowSm,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(color: AppDesignSystem.background, borderRadius: BorderRadius.circular(10)),
                        child: Center(child: Text(['🍅', '🥛', '🍞', '🥚', '🌾', '🍬', '🍵', '☕', '🍪', '🧼', '🧴', '🫒'][index], style: const TextStyle(fontSize: 24))),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p['name'], style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppDesignSystem.textPrimary)),
                            Text('₹${p['price']}', style: GoogleFonts.inter(fontSize: 12, color: AppDesignSystem.textSecondary)),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Text('Stock: ${p['stock']}', style: GoogleFonts.inter(fontSize: 11, color: p['lowStock'] ? AppDesignSystem.warning : AppDesignSystem.success, fontWeight: FontWeight.w700)),
                                if (p['lowStock']) ...[
                                  const SizedBox(width: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                    decoration: BoxDecoration(color: AppDesignSystem.warning.withOpacity(0.1), borderRadius: BorderRadius.circular(3)),
                                    child: Text('LOW', style: GoogleFonts.inter(fontSize: 8, fontWeight: FontWeight.w800, color: AppDesignSystem.warning)),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () {},
                        icon: Icon(Icons.edit_outlined, color: AppDesignSystem.primary),
                        style: IconButton.styleFrom(backgroundColor: AppDesignSystem.primary.withOpacity(0.1)),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {},
        backgroundColor: AppDesignSystem.primary,
        icon: Icon(Icons.add_rounded, color: Colors.white),
        label: Text('Add Product', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white)),
      ),
    );
  }
}