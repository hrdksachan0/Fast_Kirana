import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/design_system.dart';
import '../../widgets/product_card.dart';
import '../../data/models/product.dart';

class ComboBuilderScreen extends StatelessWidget {
  const ComboBuilderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppDesignSystem.background,
      appBar: AppBar(
        backgroundColor: AppDesignSystem.background,
        elevation: 0,
        centerTitle: true,
        title: Text('Combo Builder', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 18), fontWeight: FontWeight.w800, color: AppDesignSystem.textPrimary)),
      ),
      body: Column(
        children: [
          // Selected combo preview
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [AppDesignSystem.accent, AppDesignSystem.accentDark]),
              borderRadius: BorderRadius.circular(16),
              boxShadow: AppDesignSystem.shadowCard,
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
                  child: Icon(Icons.shopping_basket_rounded, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Custom Combo', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 16), fontWeight: FontWeight.w800, color: Colors.white)),
                      Text('3/5 items selected', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 12), color: Colors.white.withOpacity(0.9))),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                  child: Text('₹349', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 18), fontWeight: FontWeight.w800, color: AppDesignSystem.primary)),
                ),
              ],
            ),
          ),

          // Products to add
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.75,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: 8,
              itemBuilder: (context, index) {
                final names = ['Milk 1L', 'Bread', 'Eggs 6pc', 'Butter', 'Cheese', 'Curd 500g', 'Paneer 200g', 'Buttermilk'];
                final prices = [28.0, 35.0, 60.0, 55.0, 120.0, 30.0, 90.0, 20.0];
                final product = Product(
                  id: 'combo_$index',
                  name: names[index],
                  slug: names[index].toLowerCase().replaceAll(' ', '-'),
                  price: prices[index],
                  mrp: prices[index] * 1.3,
                  discount: 0,
                  isAvailable: true,
                  categoryId: 'cat_1',
                  unit: '1 pc',
                  stock: 50,
                  imageUrl: '',
                  tags: [],
                  minStock: 5,
                  costPrice: prices[index] * 0.7,
                  isFlashDeal: false,
                  isTopPick: false,
                  isBestSeller: false,
                  sortOrder: 0,
                  createdAt: DateTime.now(),
                );
                return ProductCard(product: product);
              },
            ),
          ),
        ],
      ),
    );
  }
}