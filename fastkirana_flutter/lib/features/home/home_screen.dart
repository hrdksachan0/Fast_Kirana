import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:badges/badges.dart' as badges;
import '../../core/constants/app_colors.dart';
import '../../core/network/api_client.dart';
import '../../core/utils/validators.dart';
import '../../data/models/product.dart';
import '../../data/models/category.dart';
import '../../data/repositories/product_repository.dart';
import '../../widgets/product_card.dart';

final productRepoProvider = Provider<ProductRepository>((ref) {
  return ProductRepository(ref.read(dioProvider));
});

final categoriesProvider = FutureProvider<List<Category>>((ref) async {
  return ref.read(productRepoProvider).getCategories();
});

final trendingProductsProvider =
    FutureProvider<List<Product>>((ref) async {
  return ref.read(productRepoProvider).getProducts(limit: 20);
});

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _currentIndex = 0;
  final _searchController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);
    final trendingAsync = ref.watch(trendingProductsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              backgroundColor: AppColors.primary,
              pinned: true,
              expandedHeight: 180,
              flexibleSpace: FlexibleSpaceBar(
                background: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 50, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.location_on,
                              color: Colors.white, size: 20),
                          const SizedBox(width: 4),
                          Text('Deliver to Home',
                              style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600)),
                          const Spacer(),
                          badges.Badge(
                            position: badges.BadgePosition.topEnd(
                                top: 0, end: 2),
                            badgeContent: const Text('3',
                                style: TextStyle(
                                    color: Colors.white, fontSize: 10)),
                            child: const Icon(Icons.shopping_cart_rounded,
                                color: Colors.white),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text('Hey! What are you looking for today?',
                          style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 16),
                      // Search bar
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.search_rounded,
                                color: AppColors.textSecondary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: _searchController,
                                decoration: const InputDecoration(
                                  hintText: 'Search groceries...',
                                  border: InputBorder.none,
                                  filled: false,
                                  contentPadding:
                                      EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Categories
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Shop by Category',
                        style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary)),
                    TextButton(
                      onPressed: () {},
                      child: Text('View All',
                          style: GoogleFonts.poppins(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
            ),

            categoriesAsync.when(
              data: (categories) => SliverToBoxAdapter(
                child: SizedBox(
                  height: 100,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: categories.length,
                    itemBuilder: (context, index) {
                      final category = categories[index];
                      return Container(
                        width: 80,
                        margin: const EdgeInsets.only(right: 12),
                        child: Column(
                          children: [
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                color: AppColors.background,
                                borderRadius: BorderRadius.circular(16),
                                border:
                                    Border.all(color: AppColors.borderLight),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: category.imageUrl != null
                                    ? Image.network(
                                        category.imageUrl!,
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (context, error, stackTrace) {
                                          return const Icon(
                                              Icons.shopping_basket,
                                              size: 32,
                                              color: AppColors.primary);
                                        },
                                      )
                                    : const Icon(Icons.shopping_basket,
                                        size: 32,
                                        color: AppColors.primary),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              category.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color: AppColors.textPrimary),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
              loading: () => const SliverToBoxAdapter(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(),
                  ),
                ),
              ),
              error: (e, _) => SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('Error: $e',
                      style: const TextStyle(color: AppColors.danger)),
                ),
              ),
            ),

            // Trending products
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
                child: Text('Trending Now 🔥',
                    style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary)),
              ),
            ),

            trendingAsync.when(
              data: (products) => SliverToBoxAdapter(
                child: SizedBox(
                  height: 280,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: products.length,
                    itemBuilder: (context, index) {
                      return ProductCard(product: products[index]);
                    },
                  ),
                ),
              ),
              loading: () => const SliverToBoxAdapter(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(),
                  ),
                ),
              ),
              error: (e, _) => SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('Error: $e',
                      style: const TextStyle(color: AppColors.danger)),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textMuted,
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.home_rounded), label: 'Home'),
          BottomNavigationBarItem(
              icon: Icon(Icons.search_rounded), label: 'Search'),
          BottomNavigationBarItem(
              icon: Icon(Icons.receipt_long_rounded), label: 'Orders'),
          BottomNavigationBarItem(
              icon: Icon(Icons.person_rounded), label: 'Profile'),
        ],
      ),
    );
  }
}