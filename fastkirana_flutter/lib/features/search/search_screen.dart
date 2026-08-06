import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme/design_system.dart';
import '../../data/models/product.dart';
import '../../data/repositories/product_repository.dart';
import '../../widgets/brand_card.dart';
import '../products/product_detail_screen.dart';

final searchProvider = FutureProvider.family<List<Product>, String>((ref, query) async {
  if (query.isEmpty) return [];
  return ProductRepository(ref.read(dioProvider)).getProducts(search: query);
});

final recentSearchesProvider = StateProvider<List<String>>((ref) {
  return ['Milk', 'Bread', 'Eggs', 'Butter'];
});

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _searchController = TextEditingController();
  final _trendingSearches = ['Milk', 'Butter', 'Atta', 'Cold Drinks', 'Chips', 'Paneer', 'Bread', 'Eggs'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppDesignSystem.background,
      appBar: AppBar(
        backgroundColor: AppDesignSystem.background,
        elevation: 0,
        automaticallyImplyLeading: false,
        titleSpacing: 16,
        title: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: AppDesignSystem.shadowSm,
          ),
          child: Row(
            children: [
              const Icon(Icons.search_rounded, color: AppDesignSystem.textSecondary),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _searchController,
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: 'Search groceries...',
                    border: InputBorder.none,
                  ),
                  onChanged: (value) {
                    if (value.isNotEmpty) {
                      ref.invalidate(searchProvider(value));
                    }
                  },
                ),
              ),
              if (_searchController.text.isNotEmpty)
                IconButton(
                  onPressed: () {
                    _searchController.clear();
                    setState(() {});
                  },
                  icon: const Icon(Icons.close_rounded, size: 20),
                ),
            ],
          ),
        ),
      ),
      body: _searchController.text.isEmpty ? _buildInitialContent() : _buildSearchResults(),
    );
  }

  Widget _buildInitialContent() {
    final recentSearches = ref.watch(recentSearchesProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (recentSearches.isNotEmpty) ...[
            Text('Recent Searches', style: GoogleFonts.poppins(
              fontSize: 16, fontWeight: FontWeight.w700,
            )),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: recentSearches.map((search) {
                return ActionChip(
                  label: Text(search, style: GoogleFonts.poppins(fontSize: 13)),
                  onPressed: () {
                    _searchController.text = search;
                    ref.invalidate(searchProvider(search));
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
          ],
          Text('Trending', style: GoogleFonts.poppins(
            fontSize: 16, fontWeight: FontWeight.w700,
          )),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _trendingSearches.map((search) {
              return ActionChip(
                label: Text(search, style: GoogleFonts.poppins(fontSize: 13)),
                onPressed: () {
                  _searchController.text = search;
                  ref.invalidate(searchProvider(search));
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    final productsAsync = ref.watch(searchProvider(_searchController.text));

    return productsAsync.when(
      data: (products) {
        if (products.isEmpty) {
          return Center(
            child: Column(
              children: [
                const Icon(Icons.search_off_rounded, size: 64, color: AppDesignSystem.textTertiary),
                const SizedBox(height: 16),
                Text('No products found', style: GoogleFonts.poppins(
                  fontSize: 16, color: AppDesignSystem.textSecondary,
                )),
              ],
            ),
          );
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
          itemBuilder: (context, index) => _buildProductCard(context, products[index]),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text('Error: $e', style: const TextStyle(color: AppDesignSystem.danger)),
      ),
    );
  }

  Widget _buildProductCard(BuildContext context, Product product) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => ProductDetailScreen(product: product)),
      ),
      child: BrandCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CachedNetworkImage(
                imageUrl: product.imageUrl ?? '',
                width: double.infinity,
                height: 120,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => Container(
                  height: 120,
                  color: AppDesignSystem.borderLight,
                  child: const Icon(Icons.image_not_supported),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              product.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              product.unit,
              style: GoogleFonts.poppins(fontSize: 11, color: AppDesignSystem.textSecondary),
            ),
            const SizedBox(height: 8),
            Text(
              Helpers.formatPrice(product.price),
              style: GoogleFonts.poppins(
                fontSize: 16, fontWeight: FontWeight.w800,
                color: AppDesignSystem.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}