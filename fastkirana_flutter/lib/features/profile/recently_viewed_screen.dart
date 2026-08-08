import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/design_system.dart';
import '../../widgets/product_card.dart';
import '../../data/models/product.dart';

class RecentlyViewedScreen extends StatelessWidget {
  const RecentlyViewedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppDesignSystem.background,
      appBar: AppBar(
        backgroundColor: AppDesignSystem.background,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Recently Viewed',
          style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: AppDesignSystem.textPrimary),
        ),
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.75,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: 8,
        itemBuilder: (context, index) {
          final product = Product(
            id: 'prod_$index',
            name: ['Fresh Tomatoes', 'Amul Milk', 'Britannia Bread', 'Eggs', 'Apples', 'Rice 5kg', 'Dal 1kg', 'Oil 1L'][index],
            price: [45, 28, 35, 60, 120, 450, 150, 180][index].toDouble(),
            mrp: [60, 35, 45, 75, 150, 500, 180, 210][index].toDouble(),
            categoryId: 'cat_1',
            unit: '1 kg',
            stock: 50,
            imageUrl: '',
            tags: [],
            minStock: 5,
            costPrice: 30,
            isFlashDeal: false,
            isTopPick: false,
            isBestSeller: false,
            sortOrder: 0,
            createdAt: DateTime.now(),
          );
          return ProductCard(product: product);
        },
      ),
    );
  }
}