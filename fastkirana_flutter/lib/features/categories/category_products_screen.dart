import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme/design_system.dart';
import '../../data/models/product.dart';
import '../../data/models/category.dart';
import '../../data/repositories/product_repository.dart';
import '../../providers/product_provider.dart';
import '../../widgets/product_card.dart';
import '../products/product_detail_screen.dart';

class CategoryProductsScreen extends ConsumerStatefulWidget {
  final Category category;
  const CategoryProductsScreen({super.key, required this.category});

  @override
  ConsumerState<CategoryProductsScreen> createState() => _CategoryProductsScreenState();
}

class _CategoryProductsScreenState extends ConsumerState<CategoryProductsScreen> {
  String? _sortBy;

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsProvider(widget.category.id));

    return Scaffold(
      backgroundColor: AppDesignSystem.background,
      appBar: AppBar(
        title: Text(widget.category.name, style: GoogleFonts.poppins(
          fontWeight: FontWeight.w700, color: Colors.white,
        )),
        backgroundColor: AppDesignSystem.primary,
        elevation: 0,
      ),
      body: productsAsync.when(
        data: (products) {
          if (products.isEmpty) {
            return Center(child: Text('No products found', style: GoogleFonts.poppins(color: AppDesignSystem.textSecondary)));
          }
          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.75,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: products.length,
            itemBuilder: (context, index) => ProductCard(
              product: products[index],
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => ProductDetailScreen(product: products[index])),
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('Error: $e', style: const TextStyle(color: AppDesignSystem.danger)),
        ),
      ),
    );
  }
}