import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/design_system.dart';
import '../../widgets/product_card.dart';
import '../../data/models/product.dart';

class SearchResultsScreen extends StatelessWidget {
  final String query;
  const SearchResultsScreen({super.key, required this.query});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppDesignSystem.background,
      appBar: AppBar(
        backgroundColor: AppDesignSystem.background,
        elevation: 0,
        title: Text('Results for "$query"', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: AppDesignSystem.textPrimary)),
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.75,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: 10,
        itemBuilder: (context, index) {
          final product = Product(
            id: 'prod_$index',
            name: ['Fresh Tomatoes', 'Amul Milk', 'Britannia Bread', 'Eggs', 'Apples', 'Rice 5kg', 'Dal 1kg', 'Oil 1L', 'Soap', 'Shampoo'][index],
            slug: 'prod-$index',
            price: [45, 28, 35, 60, 120, 450, 150, 180, 25, 199][index].toDouble(),
            mrp: [60, 35, 45, 75, 150, 500, 180, 210, 35, 250][index].toDouble(),
            discount: 15.0,
            categoryId: 'cat_1',
            unit: '1 kg',
            stock: 50,
            isAvailable: true,
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