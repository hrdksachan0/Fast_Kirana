import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/design_system.dart';
import '../../core/theme/responsive.dart';
import '../../core/routes/page_transitions.dart';
import '../../core/network/api_client.dart';
import '../../data/models/product.dart';
import '../../data/repositories/product_repository.dart';
import '../../widgets/product_card.dart';
import '../../widgets/empty_state.dart';
import '../products/product_detail_screen.dart';

final productsProvider = FutureProvider<List<Product>>((ref) {
  return ProductRepository(ref.read(dioProvider)).getProducts(limit: 50);
});

class ProductsScreen extends ConsumerWidget {
  const ProductsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(productsProvider);

    return Scaffold(
      backgroundColor: AppDesignSystem.background,
      appBar: AppBar(
        title: Text(
          'All Products',
          style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ResponsiveContainer(
        maxWidth: Responsive.wideMaxContentWidth,
        fillHeight: true,
        child: productsAsync.when(
          data: (products) {
            if (products.isEmpty) {
              return EmptyState(
                emoji: '📦',
                title: 'No products found',
                subtitle: 'Check back later — new products are added every day!',
                bgTint: const Color(0xFFFFF7ED),
                ctaLabel: 'Go Back',
                onCta: () => Navigator.pop(context),
              );
            }
            return LayoutBuilder(
              builder: (context, constraints) {
                final columns = (constraints.maxWidth / 155).floor().clamp(2, 6);
                final itemAspect = constraints.maxWidth < 360 ? 0.58 : (columns > 2 ? 0.66 : 0.62);

                return GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    childAspectRatio: itemAspect,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: products.length,
                  itemBuilder: (context, index) => ProductCard(
                    product: products[index],
                    onTap: () => Navigator.push(
                      context,
                      FadeSlideRoute(page: ProductDetailScreen(product: products[index])),
                    ),
                  ),
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator(color: AppDesignSystem.primary)),
          error: (e, _) => Center(
            child: Text('Error: $e', style: const TextStyle(color: AppDesignSystem.danger)),
          ),
        ),
      ),
    );
  }
}